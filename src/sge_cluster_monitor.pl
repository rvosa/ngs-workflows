#!/usr/bin/perl
use strict;
use Getopt::Std;
use YAML::Any qw/LoadFile/;
use Net::SSH qw/sshopen2 ssh_cmd/;
use File::Basename;
use threads;

my $head_node = 'node.place.edu';
my $max_threads = 13;
my $has_errors;
my @flow_control_labels = ();

my $usage =  $0.' -U cluser_user_id -G cluser_user_group [-p] sample_file_prefix reference'.qq|

This program takes a path to the prefix (without extension) of a sanger formated fastq file, 
splits it (and its pair if -p) into subset files in a seperate job directory, creates qsub
jobs to align each subset (and its corresponding pair subset) against the supplied reference
to produce a sorted unfiltered bam file.  It will scp the job directory with the qsub job scripts,
fastq subsets, and reference files to the cluster head, submit the qsub job scripts, monitor the
head node (with ssh) until all jobs are completed, and then scp all job directory back.  It will
then merge, sort, and split the subset bam files into two bam files, aligned.bam, and unalinged.bam,
in the same directory as the sample_file_prefix.

This version requires that you have lowprio access on the hared Cluster Resource with the cluser_user_id provided,
and a cluster home directory /home/cluser_user_group/cluser_user_id.  It will do all cluster work in that home directory.
|;

my %opt = ();
getopts('pU:G:', \%opt);
my $sample_prefix = shift or die $usage;
my $reference = shift or die $usage;
my $cluser_user_id = $opt{U} or die $usage;
my $cluster_group_id = $opt{G} or die $usage;
my $root_dir = join('/', '/home', $cluster_group_id, $cluser_user_id);

my $working_directory = File::Basename::dirname($sample_prefix);
chdir($working_directory);
$sample_prefix = File::Basename::basename($sample_prefix); # the directory is no longer needed

@flow_control_labels = ($opt{p}) ? 
   qw( pair1 pair2 sampe ) :
   qw( single_end samse );

my @submissions = ();
my $running_threads = 0;

my @date = localtime;

my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
my @days = qw(Sun Mon Tue Wed Thu Fri Sat);

my $year = $date[5] + 1900;
my $mon = $months[ $date[4] ];
my $day = $days[ $date[6] ];

my $job_name = join('_',$year, $mon, $day, 'align' , $$);
my $merged_bam_file = join('.', $job_name, 'bam');

if (system('mkdir', $job_name)) {
    print STDERR "Could not create ${job_name} directory\n";
    exit(1);
}

# you might need to index the reference as a separate job on the queue,
# or keep indexed references in your home directory that the job
# scripts reference instead of sending it and its indexes to 
# the head node each time
`cp ${reference}* $job_name`;
if ($?) {
    print STDERR "Could not copy ${reference} to ${job_name} directory $!\n";
    exit(1);
}

my @job_subsets = ();
if ($opt{p}) {
    # files should be named sample_prefix_1.fastq and sample_prefix_2.fastq
    foreach my $fastq (<${sample_prefix}_1.fastq>) {
        my $fastq_pair = $fastq;
        $fastq_pair =~ s/1.fastq$/2.fastq/;
        unless (-e $fastq_pair) {
            print STDERR "PAIR ${fastq_pair} does not exist for ${fastq} are you sure this is paired?\n";
            exit(1);
        }
        &split_fastq($fastq, $job_name);
        &split_fastq($fastq_pair, $job_name);
        push @job_subsets, [$fastq, $fastq_pair];
    }
}
else {
    # file should be named sample_prefix.fastq
    my $fastq = "${sample_prefix}.fastq";
    unless (-e $fastq) {
        print STDERR "fastq ${fastq} does not exist!\n";
        exit(1);
    }
    &split_fastq($fastq, $job_name);
    push @job_subsets, [$fastq];
}

while (my $subset = shift @job_subsets) {
    my $thr = threads->create(\&prepare_working_directory, $job_name, $reference, @{ $subset });
    print STDERR "Thread ".$thr->tid." Started with working_directory ${job_name}\n";
    $running_threads++;

    while ($running_threads > 0 && $running_threads == $max_threads) {
        print STDERR "${running_threads} threads running, will wait for less than ${max_threads}\n";
        sleep 10;

        push @submissions, &monitor_joinable_threads;
        my $joined_threads = @submissions;
        $running_threads -= $joined_threads;
    }
}

while (threads->list(threads::running)) {
    sleep 10;
    push @submissions, &monitor_joinable_threads;
}

exit(1) if ($has_errors);

my $job_ids = {};
my $submission_files = {};
my $count;

while (my $submission = shift @submissions) {
	my $jobID = submitQueueFile($submission);
    $job_ids->{$jobID} = 1;
    $submission_files->{$jobID} = $submission;
    $count++;
}
print STDERR "$count jobs submitted.\n";

#Monitor cluster to wait for jobs to finish
sleep 10 while (&jobs_in_progress($job_ids, $submission_files));

my @complete_bams = ();
my $num_unsorted_bams = @complete_bams;
if ($num_unsorted_bams) {
    if (system('samtools','merge', $merged_bam_file, @complete_bams)) {
        print STDERR "Could not merge bams!\n";
        exit(1);
    }
    my $unaligned = my $aligned = $merged_bam_file;
    $unaligned =~ s/\.bam$/.unaligned/;
    $aligned =~ s/\.bam$/.aligned/;

    `samtools view -h ${merged_bam_file} | filter_sam.pl -a | samtools view -bS - | samtools sort - $aligned`;
    if ($?) {
        print STDERR "Could not create ${aligned} $!\n";
        exit(1);
    }

    `samtools view -h ${merged_bam_file} | filter_sam.pl -u | samtools view -bS - | samtools sort - $unaligned`;
    if ($?) {
        print STDERR "Could not create ${unaligned} $!\n";
        exit(1);
    }
    unlink $merged_bam_file;
}
else {
    print STDERR "NO BAM FILES PRODUCED!!!\n";
    $has_errors++;
}
`rm -rf ${job_name}`;
exit($has_errors);

sub prepare_working_directory {
    my $job_name = shift;
    my $reference = shift;
    my $fastq = shift;
    my $pair = shift;

    foreach ('status','queue') {
        if (system('mkdir', '-p', join('/', $job_name, $_))) {
            print STDERR "Could not create new Working Directory ${job_name}/${_}\n";
            exit(1);
        }
    }

    my $tmp_bam_file = join('/', $job_name, $job_name.'.tmp.bam');
    my $sai = $fastq;
    $sai =~ s/\.fastq/.sai/;
    my $pair_sai;
    if ($pair) {
        $pair_sai = $pair;
        $pair =~ s/\.fastq/.sai/;
    }

    my $status_dir = join('/', $job_name, 'status');
    my $queue_dir = join('/', $job_name, 'queue');

    my $status_file = join('/', $status_dir, ${job_name}.'.stat');
    my $queue_file = join('/', $queue_dir, ${job_name});

    my $complete_file = $queue_file;
    $complete_file =~ s/queue/status/;
    my $running_file = $complete_file;
    $running_file .= '.running';
    $complete_file .= '.complete';
    $queue_file .= ".q";

    open(QOUT, '>', $queue_file) or die "Can not open ${queue_file}: $!";

print QOUT <<EOS;
#!/bin/tcsh
#
#\$ -S /bin/tcsh -cwd
#\$ -o ${root_dir}/${status_file} -j y

echo \$HOSTNAME\n

bwa aln ${reference} ${fastq} > $sai
EOS

   if ($opt{p}) {
print QOUT <<SAI;
echo "pair1: \$\?" > ${root_dir}/${running_file}
bwa aln ${reference} ${pair} > ${pair_sai}
echo "pair2: \$\?" >> ${root_dir}/${running_file}

bwa sampe $reference $sai $pair_sai $fastq $pair | samtools -bS - | samtools sort - $tmp_bam_file
echo "sampe: \$\?" >> ${root_dir}/${running_file}

SAI
    }
    else {
print QOUT <<SAI;
echo "single_end: \$\?" > ${root_dir}/${running_file}
bwa samse $reference $sai $fastq | samtools -bS - | samtools sort $tmp_bam_file
echo "samse: \$\?" >> ${root_dir}/${running_file}

SAI
    }

print QOUT <<EOS;
mv ${root_dir}/${running_file} ${root_dir}/${complete_file}
rm ${root_dir}/${reference}

EOS
    close(QOUT);

    `scp -r ${job_name} ${head_node}:${root_dir}`;
    if ($?) {
        return { 'error' => "Problem copying ${job_name} to head_node $!\n" };
    }
    
    #remove local copies of working files
    `rm -rf ${job_name}`;
    if ($?) {
        print STDERR "Could not rm ${job_name} $!\nIt will probably copy results into it\n";
    }

    return {
        'name' => $job_name,
        'tmp_bam_file' => $tmp_bam_file.'.bam',
        'queue_file' => $queue_file,
        'running_file' => $running_file,
        'complete_file' => $complete_file
    };
}

sub job_has_error {
    my $job_id = shift;
    my $submission_files = shift;

    my $command = "scp -r ${head_node}:".$submission_files->{name}." ".$submission_files->{name};
    `$command`;
    if ($?) {
        print STDERR "Could not copy ".$submission_files->{name}." back $!\n";
        exit(1);
    }

    if (-e $submission_files->{'complete_file'}) {
        print STDERR "Job ${job_id} (".$submission_files->{queue_file}.") ran all the way through\n";
        return &parse_job_report_file($submission_files->{'complete_file'});
    }
    elsif (-e $submission_files->{'running_file'}) {
        print STDERR "Job ${job_id}(".$submission_files->{queue_file}.") appears to have died part of the way through\n";

        ## It is technically possible that the job may have died moving the running file to the complete file
        return &parse_job_report_file($submission_files->{'running_file'});
    }
    else {
        print STDERR "Job ${job_id} (".$submission_files->{queue_file}.") appears to have lost the running file: ".$submission_files->{'running_file'}." and complete file: ".$submission_files->{'complete_file'}."!!!\n";
        return 1;
    }
}

sub parse_job_report_file {
    my $job_report_file = shift;
    return unless (-e $job_report_file);
    my $job_status = YAML::Any::LoadFile($job_report_file);
    my $has_errors;

    foreach my $required_label (@flow_control_labels) {
        if (exists( $job_status->{$required_label} )) {
            unless ($job_status->{$required_label} == 0) {
                $has_errors = 1;
                print STDERR "  - ${required_label} ended in error\n";
            }
        }
        else {
            $has_errors = 1;
            print STDERR "  - ${required_label} did not run\n";
        }
    }

    return $has_errors;
}

sub submitQueueFile {
    my $submission = shift;
    my $queueSub = $submission->{'queue_file'};

    my $job_name = $submission->{name};

    #submit q file
	#For some reason the cluster is now ignoring this qsub 10% of the time
	# We need to add a check to fix this
	my $check_for_submit = 1;
	my $jobID;
	while($check_for_submit) {
	    my $test = ssh_cmd($head_node, "qsub ${queueSub}");
	    print STDERR $test;
	    #Test contains:
	    # Your job <Job ID> ("*.q") has been submitted.
	    $test =~ /job (\d+) /;
	    $jobID = $1;
		if($jobID > 0) { 
			undef $check_for_submit;
		}
        sleep 1;
	}

    print STDERR $submission->{queue_file}." submitted with ID ${jobID}\n";
    return $jobID;
}

sub jobs_in_progress {
    my ($job_ids, $submission_files) =  @_;
    my $still_running;

    # check for jobs with -s pr (e.g. pending or running)
    # as long as this returns entries in the job_ids hash
    # we are still_running
    sshopen2($head_node, *READER, undef, 'qstat -s pr');
    LINE: while (my $line = <READER>) {
        $line =~ s/^\s+//g; # qstat out introduced indenting whitespace to jobID
        my @line_split = split('\s+', $line);

        my $job_id = $line_split[0];
        if(exists $job_ids->{$job_id}) {
            if ($line_split[4] eq 'r' || $line_split[4] eq 'qw') {
                $still_running = 1;
                next LINE;
            }

            if($line_split[4] eq "Eqw") {   #error state.
                # I am not sure when this ever happens, or if it prints with -s pr
                print STDERR "Eqw in ${job_id} deleting job\n";
                my $submission = $submission_files->{$job_id};
                delete $job_ids->{$job_id};
                delete $submission_files->{$job_id};

                my $sample_status = ssh_cmd( $head_node, "qdel ${job_id}" );
                print STDERR $sample_status;

                if (job_has_error($job_id, $submission)) {                    
                    $has_errors++;
                }
                else {
                    if (-e $submission->{tmp_bam_file}) {
                        ssh_cmd( $head_node, "rm -rf ".$submission->{name} );
                        push @complete_bams, $submission->{tmp_bam_file};
                    }
                    else {
                        print STDERR $submission->{tmp_bam_file}." is missing!!!\n";
                        $has_errors++;
                    }
                }
            }
        }
    }
    close READER;

    # go ahead and check for completed entries as well
    sshopen2($head_node, *READER, undef, 'qstat -s z');
    while (my $line = <READER>) {
        $line =~ s/^\s+//g; # qstat out introduced indenting whitespace to jobID
        my @line_split = split('\s+', $line);
        
        my $job_id = $line_split[0];
        if(exists $job_ids->{$job_id}) {
            print STDERR "$job_id appears to have finished\n";
            my $submission = $submission_files->{$job_id};
            delete $submission_files->{$job_id};
            delete $job_ids->{$job_id};

            if (job_has_error($job_id, $submission)) {
                $has_errors++;
            }
            else {
                if (-e $submission->{tmp_bam_file}) {
                    ssh_cmd( $head_node,"rm -rf ".$submission->{name} );
                    push @complete_bams, $submission->{tmp_bam_file};
                }
                else {
                    print STDERR $submission->{tmp_bam_file}." is missing!!!\n";
                    $has_errors++;
                }
            }
        }
    }
    close READER;

    unless ($still_running) {
        foreach my $dropped_job (keys %{$job_ids}) {
            print STDERR "Your job $dropped_job has finished.\n";

            # these would have fallen out of the -s z queue before the next ssh attempt
            my $submission = $submission_files->{$dropped_job};
            delete $job_ids->{$dropped_job};
            delete $submission_files->{$dropped_job};

            if (job_has_error($dropped_job, $submission)) {
                $has_errors++;
            }
            else {
                if (-e $submission->{tmp_bam_file}) {
                    ssh_cmd( $head_node, "rm -rf ".$submission->{name} );
                    push @complete_bams, $submission->{tmp_bam_file};
                }
                else {
                    print STDERR $submission->{tmp_bam_file}." is missing!!!\n";
                    $has_errors++;
                }
            }
        }
    }
    return $still_running;
}

sub monitor_joinable_threads {
    my @joined_thread_submissions = ();
    foreach my $joinable_thread (threads->list(threads::joinable)) {
        my $submission = $joinable_thread->join();
        if ($submission->{error}) {
            print STDERR $submission->{error};
            $has_errors++;
        }
        else {
            push @joined_thread_submissions, $submission;
        }
    }
    return @joined_thread_submissions;
}

sub split_fastq {
    my $fastq = shift;
    my $job_dir = shift;

    my $subset = 1;
    my $entries_per_subset = 10; # should be no more than 20% of the total

    open (my $f_in, '<', $fastq) or die "Could not open ${fastq} $!\n";

    my $subset_fastq = join('/', $job_dir, File::Basename::basename($fastq));
    $subset_fastq =~ s/(\.\w+)$/_$subset.$1/;
    
    open (my $f_out, '>', $subset_fastq) or die "Could not write to ${subset_fastq} $!\n";

    my $entries_processed = 0;
    while (my $fql = <$f_in>) {
        if ($fql =~ m/^@/ && ($entries_processed == $entries_per_subset)) {
            close $f_out;
            my $old_subset = $subset;
            $subset++;
            $subset_fastq =~ s/\_$old_subset.(\w+)$/_$subset.$1/;
            open ($f_out, '>', $subset_fastq) or die "Could not write to ${subset_fastq} $!\n";
        }
        print $f_out $fql;
        $entries_processed++;
    }
    close $f_out;
    return;
}
