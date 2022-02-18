#!bin/zsh

## show_file_by_row show {$2}th line of file named {$1}
## $1 is the file name
## $2 is the start row 
show_file_by_row(){
	head -$2 $1 | tail -1
}

## delete_and_run delete {$2}th line of file named {$1} and run shell scripts
## $1 is the file name
## $2 is the start row 
delete_and_run(){
	sed -i "`echo $2`d" $1  && sh debug.sh
}

