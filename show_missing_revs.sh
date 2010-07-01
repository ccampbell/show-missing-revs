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
    echo "-h help => show these instructions"
    exit 1
}

repo=
branch=
username=

# magically determine the repo url
repo_url=`svn info | grep "URL:" | cut -d ' ' -f 2`
branch_url=`echo $repo_url | grep "/branches"`

# are we in a branch?
if [ $branch_url ] ; then
    repo=`echo $branch_url | sed s:/branches:' ':g | cut -d ' ' -f 1`
else
    repo=`echo $repo_url | sed s:/trunk:' ':g | cut -d ' ' -f 1`
fi

# gather options
while getopts 'hu:b:' OPTION
do
    case $OPTION in
    b)    if [ $OPTARG == "trunk" ]
          then
              branch="$repo/trunk"
          else
              branch="$repo/branches/$OPTARG"
          fi
          ;;
    u)    username="$OPTARG"
          ;;
    h)    usage_and_exit
          ;;
    esac
done

if [ ! $branch ] ; then
    usage_and_exit
fi

# put all revisions that have not been merged into a text file
svn mergeinfo --show-revs eligible $branch > eligible_revs.txt

# turn these revisions into an array
revision_list=`cat eligible_revs.txt`
revisions=(`echo $revision_list | tr '\n' ' '`) 

# get the count of the last item
# (-1 because there is a new line at end of the file)
final_count=${#revisions[*]}-1

#revision range
first_revision=${revisions[0]}
final_revision=${revisions[$final_count]}

# get the svn log for this range and write it out to a file for now
svn log $branch -$first_revision:$final_revision > revisions_in_range.txt

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
