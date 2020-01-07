#!/bin/bash
# A bash script to run the Dedalus python code
# Takes in arguments:
#	$ sh run.sh -n <name of experiment> <- not optional
#				-c <cores>
#				-v <version: what scripts to run>

# Current datetime
DATETIME=`date +"%Y-%m-%d_%Hh%M"`

# if:
# VER = 0 (Full)
#	-> run the script, merge, plot frames, create gif, create mp4, etc
# VER = 1
#	-> run the script
# VER = 2
#	-> merge, plot frames, create gif, create mp4, etc

while getopts n:c:v: option
do
	case "${option}"
		in
		n) NAME=${OPTARG};;
		c) CORES=${OPTARG};;
		v) VER=${OPTARG};;
	esac
done

# check to see if arguments were passed
if [ -z "$NAME" ]
then
	echo "-n, No name specified, aborting script"
	exit 1
fi
if [ -z "$VER" ]
then
	VER=0
	echo "-v, No version specified, using VER=$VER"
fi
if [ -z "$CORES" ]
then
	CORES=2
	echo "-c, No number of cores specified, using CORES=$CORES"
fi

###############################################################################

# The command and arguments for running scripts with mpi
mpiexec_command="mpiexec"
# Name of the main code file
code_file='main.py'
# Path to snapshot files
snapshot_path="snapshots"
# Name of merging file
merge_file="merge.py"
# Name of plotting file
plot_file="plot_slices.py"
# Name of output directory
output_dir="outputs"
# Path to frames
frames_path='frames'
# Name of gif creation file
gif_cre_file="create_gif.py"

###############################################################################
# run the script
#	if (VER = 0, 1)
if [ $VER -eq 0 ] || [ $VER -eq 1 ]
then
	echo ''
	echo '--Running script--'
	# Check if snapshots already exist. If so, remove them
	if [ -e $snapshot_path ]
	then
		echo "Removing old snapshots"
		rm -rf $snapshot_path
	fi
    echo "Running Dedalus script for local pc"
    # mpiexec uses -n flag for number of processes to use
    ${mpiexec_command} -n $CORES python3 $code_file
    echo ""
	echo 'Done running script'
fi

###############################################################################
# merge snapshots
#	if (VER = 0, 2)
if [ $VER -eq 0 ] || [ $VER -eq 2 ]
then
	echo ''
	echo '--Merging snapshots--'
	# Check to make sure snapshots folder exists
	echo "Checking for snapshots in directory: $snapshot_path"
	if [ -e $snapshot_path ]
	then
		echo "Found snapshots"
	else
		echo "Cannot find snapshots. Aborting script"
		exit 1
	fi
	# Check if snapshots have already been merged
	if [ -e $snapshot_path/snapshots_s1.h5 ]
	then
		echo "Snapshots already merged"
	else
		echo "Merging snapshots"
		${mpiexec_command} -n $CORES python3 $merge_file $snapshot_path
	fi
    echo 'Done merging snapshots'
fi

###############################################################################
# plot frames - note: already checked if snapshots exist in step above
#	if (VER = 0, 2)
if [ $VER -eq 0 ] || [ $VER -eq 2 ]
then
	echo ''
	echo '--Plotting frames--'
	if [ -e frames ]
	then
		echo "Removing old frames"
		rm -rf frames
	fi
	echo "Plotting 2d slices"
	${mpiexec_command} -n $CORES python3 $plot_file $NAME $snapshot_path/*.h5
	echo 'Done plotting frames'
fi

###############################################################################
# create gif
#	if (VER = 0, 2)
if [ $VER -eq 0 ] || [ $VER -eq 3 ]
then
	echo ''
	echo '--Creating gif--'
	gif_name="${DATETIME}.gif"
	# Check if output directory exists
	if [ ! -e $output_dir ]
	then
		echo "Creating $output_dir directory"
		mkdir $output_dir
	fi
	# Check if gis already exists
	if [ -e $output_dir/$gif_name ]
	then
		echo "Overwriting $gif_name"
		rm $output_dir/$gif_name
	fi
	files=/$frames_path/*
	if [ -e $frames_path ] && [ ${#files[@]} -gt 0 ]
	then
		echo "Executing gif script"
		python3 $gif_cre_file $NAME $output_dir/$gif_name $frames_path
	else
		echo "No frames found"
	fi
	echo 'Done with gif creation'
fi

echo ''
echo 'Done running experiment'
echo ''
