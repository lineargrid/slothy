#!/bin/bash

# Source colors (create this file or paste the content below)
source ~/.config/scripts/color.sh 2>/dev/null || {
	GRN="\033[1;32m"
	YEL="\033[1;33m"
	BLU="\033[1;34m"
	RED="\033[1;31m"
	MAG="\033[1;35m"
	RST="\033[0m"
}

# Check if inside a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	echo -e "${RED}Error: Not inside a Git repository.${RST}"
	exit 1
fi

echo -e "${BLU}=== Git Status ===${RST}"
git status --short

# Get list of changed/untracked files
mapfile -t files < <(git status --porcelain | grep -E '^(A|M|??|D|R)' | awk '{print $2}')

if [[ ${#files[@]} -eq 0 ]]; then
	echo -e "${YEL}No changes to commit. Repository is clean.${RST}"
	read -p "Push current branch anyway? (y/N): " push_anyway
	[[ $push_anyway =~ ^[Yy]$ ]] || exit 0
else
	echo -e "\n${MAG}Files not staged or untracked:${RST}"
	for i in "${!files[@]}"; do
		echo -e "  ${YEL}$((i + 1))${RST}) ${files[i]}"
	done

	echo -e "\n${GRN}Select files to add (e.g. 1 3 5, or 'all'):${RST}"
	read -r selection

	if [[ "$selection" == "all" ]]; then
		git add -A
		echo -e "${GRN}All files added.${RST}"
	else
		to_add=()
		for num in $selection; do
			idx=$((num - 1))
			if [[ $idx -ge 0 && $idx -lt ${#files[@]} ]]; then
				to_add+=("${files[idx]}")
			else
				echo -e "${RED}Invalid number: $num${RST}"
			fi
		done

		if [[ ${#to_add[@]} -eq 0 ]]; then
			echo -e "${RED}No valid files selected. Aborting.${RST}"
			exit 1
		fi

		git add "${to_add[@]}"
		echo -e "${GRN}Added: ${to_add[*]}${RST}"
	fi

	# Commit message
	echo -e "\n${GRN}Enter commit message:${RST}"
	read -r commit_msg
	if [[ -z "$commit_msg" ]]; then
		commit_msg="update: $(date +'%Y-%m-%d %H:%M')"
		echo -e "${YEL}Using default: $commit_msg${RST}"
	fi

	git commit -m "$commit_msg"
	echo -e "${GRN}Committed: \"$commit_msg\"${RST}"
fi

# Branch selection
echo -e "\n${BLU}=== Branches ===${RST}"
mapfile -t branches < <(git branch --list | sed 's/* //; s/^[[:space:]]*//')

for i in "${!branches[@]}"; do
	current=""
	[[ $(git rev-parse --abbrev-ref HEAD) == "${branches[i]}" ]] && current=" ${YEL}(current)${RST}"
	echo -e "  ${YEL}$((i + 1))${RST}) ${branches[i]}$current"
done

echo -e "\n${GRN}Select branch to push to (number), or type a new branch name:${RST}"
read -r branch_choice

if [[ "$branch_choice" =~ ^[0-9]+$ ]]; then
	idx=$((branch_choice - 1))
	if [[ $idx -ge 0 && $idx -lt ${#branches[@]} ]]; then
		target_branch="${branches[idx]}"
	else
		echo -e "${RED}Invalid branch number.${RST}"
		exit 1
	fi
else
	# User typed a new branch name
	target_branch="$branch_choice"
	echo -e "${YEL}Creating and switching to new branch: $target_branch${RST}"
	git checkout -b "$target_branch"
fi

# Final confirmation
echo -e "\n${MAG}Ready to push to: $target_branch${RST}"
read -p "Confirm push? (y/N): " confirm
if [[ $confirm =~ ^[Yy]$ ]]; then
	git push -u origin "$target_branch"
	echo -e "${GRN}Successfully pushed to $target_branch!${RST}"
else
	echo -e "${YEL}Push cancelled.${RST}"
fi
