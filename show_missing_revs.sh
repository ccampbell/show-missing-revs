#!/usr/bin/env sh
#
# Copyright 2010 Craig Campbell
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# prints out usage instructions
#
# @return string
#
usage_and_exit()
{
    echo "usage instructions:\n"
    echo "required arguments:"
    echo "-b branch => name of branch that you want to merge to current branch\n"
    echo "optional arguments:"
    echo "-u username => target svn user to see what he/she has not yet merged"
    echo "-v verbose => show more information about what is happening as it happens"
    echo "-h help => show these instructions"
    exit 1
}

repo=
branch=
username=
verbose=

# magically determine the repo url
repo_url=`svn info | grep "URL:" | cut -d ' ' -f 2`
branch_url=`echo $repo_url | grep "/branches"`

# are we in a branch?
if [ $branch_url ] ; then
    merge_to=`echo $branch_url | sed s:/branches/:' ':g | cut -d ' ' -f 2 | cut -d '/' -f 1`
    repo=`echo $branch_url | sed s:/branches:' ':g | cut -d ' ' -f 1`
    target=$repo/branches/$merge_to
else
    merge_to="trunk"
    repo=`echo $repo_url | sed s:/trunk:' ':g | cut -d ' ' -f 1`
    target=$repo/$merge_to
fi

# gather options
while getopts 'vhu:b:' OPTION
do
    case $OPTION in
    b)    if [ $OPTARG == "trunk" ] ; then
              merge_from="trunk"
              branch="$repo/trunk"
          else
              merge_from=$OPTARG
              branch="$repo/branches/$OPTARG"
          fi
          ;;
    u)    username="$OPTARG"
          ;;
    v)    verbose=true
          ;;
    h)    usage_and_exit
          ;;
    esac
done

if [ ! $branch ] ; then
    usage_and_exit
fi

# craft a nice sentence in english of what we are doing
message="displaying revisions in ${merge_from}"

if [ ! $branch_url ] ; then
    message=$message" branch"
fi

if [ $username ] ; then
    message=$message" by ${username}"
fi

message=$message" that have not yet been merged to ${merge_to}"

if [ $branch_url ] ; then
    message=$message" branch"
fi

# tell the user what we are doing
echo $message

if [ ! $verbose ] ; then
    echo ""
fi

# put all revisions that have not been merged into a text file
if [ $verbose ] ; then
    echo "getting missing revisions from svn..."
fi

svn mergeinfo --show-revs eligible $branch $target > eligible_revs.txt

# turn these revisions into an array
revision_list=`cat eligible_revs.txt`
revisions=(`echo $revision_list | tr '\n' ' '`) 

# if everything has already been merged then let's stop
if [ ${#revisions[*]} == "0" ] ; then
    echo "everything from ${merge_from} has been merged to ${merge_to}"
    exit 0
fi

# get the count of the last item
# (-1 because there is a new line at end of the file)
final_count=${#revisions[*]}-1

#revision range
first_revision=${revisions[0]}
final_revision=${revisions[$final_count]}

# get the svn log for this range and write it out to a file for now
if [ $verbose ] ; then
    echo getting the log from svn"..."
fi

svn log -$first_revision:$final_revision $branch > revisions_in_range.txt

if [ $verbose ] ; then
    echo "processing results...\n"
fi

# find the intersection between the missing revs and the logs
output=
for i in "${revisions[@]}"
    do
        grep_result=`cat revisions_in_range.txt | grep -n $i | cut -d '|' -f 1,2 -s`
        
        line_number=`echo $grep_result | cut -d ':' -f 1`
        commit_info=`echo $grep_result | cut -d ':' -f 2`
        
        # commit message comes two lines after the line
        typeset -i message_line=$((line_number+2))
        
        # grab the commit message
        message=`tail +$message_line revisions_in_range.txt | head -1`
        
        # append the commit message to the other info
        commit_info=$commit_info" | "$message
        
        output=$output$commit_info"\n"
    done

if [ ! $username ] ; then
    # if we are not targeting a specific username then output the revisions that intersect
    echo $output
else
    # output the revisions for just this user
    echo $output | grep $username
fi

# cleanup - remove the temporary files
rm eligible_revs.txt
rm revisions_in_range.txt

exit 0
