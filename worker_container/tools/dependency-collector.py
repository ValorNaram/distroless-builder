#!/bin/python3
import os
import subprocess
import sys
import shutil

# TODO: Improve overall stability and reliability

dependency_map = {}
destFolder = ""

def save_to_dest(src):
	if not os.path.exists(destFolder):
		os.makedirs(destFolder)

	dirname = os.path.dirname(src)
	if not dirname == ".":
		os.makedirs(destFolder + dirname, exist_ok=True)

	# no os.path.join as 'src' will likely contain a leading '/' (forward slash) causing the value of 'destFolder' to be stripped. Hence we use normal concat here.
	dest_file = destFolder + src
	if not os.path.exists(dest_file):
		print(f"\033[0;34mCopying '\033[0;m{src}\033[0;34m' to '\033[0;m{dest_file}\033[0;34m' ...\033[0;m")
		if os.path.isdir(src):
			shutil.copytree(src, dest_file)
			return True
		shutil.copy2(src, dest_file)

def save_to_dependency_map(lib, binary):
	print(f"\033[0;34mSaving '\033[0;m{lib}\033[0;34m' in dependency tree ...\033[0;m")
	if not binary in dependency_map:
		dependency_map[binary] = []
	dependency_map[binary].append(lib)

# TODO: Improve code
def get_dependencies_of_component(component: str):
	dependencies = []
	
	try:
		ldd_result = subprocess.check_output(['ldd', component], text=True, stderr=subprocess.STDOUT)
	except:
		return dependencies

	for line in ldd_result.split("\n"):
		if line == "":
			continue
		line = line.replace("\t", "")
		if line == "statically linked" or line == "not a dynamic executable":
			continue
		if line.find("=>") > -1:
			libName, libPath = line.split(" => ")
			libPath = libPath.split("(")[0]
			dependencies.append(libPath.strip())
		else:
			libPath = line.split("(")[0].strip()
			if os.path.exists(libPath):
				dependencies.append(libPath)
	
	return dependencies

def build_dependency_tree_of_single_binary(binary):
	result = get_dependencies_of_component(binary)
	if len(result) == 0:
		return

	for lib in result:
		if not lib in dependency_map:
			save_to_dest(lib)
			save_to_dependency_map(lib, binary)
			build_dependency_tree_of_single_binary(lib)

def traverse_dir_and_build_dependency_tree_of_each_single_binary(directory):
	for path in os.listdir(directory):
		full_path = os.path.join(directory, path)
		if os.path.isdir(full_path):
			traverse_dir_and_build_dependency_tree_of_each_single_binary(full_path)
		elif os.path.isfile(full_path):
			build_dependency_tree_of_single_binary(full_path)

if __name__ == "__main__":
	arguments = sys.argv

	del arguments[0]
	destFolder = arguments[0]
	del arguments[0]

	for argument in arguments:
		print()
		print(f"\033[0;35mAnalyzing binary '{argument}' for untracked dependencies ...\033[0;m")
		if os.path.isfile(argument):
			build_dependency_tree_of_single_binary(argument)
		elif os.path.isdir(argument):
			traverse_dir_and_build_dependency_tree_of_each_single_binary(argument)

	yaml_output = "# keys represent the path to the binaries. Their respective value is a list containing paths to libs the respective binary depends on.\n"
	for binary in dependency_map:
		yaml_output += f"{binary}:\n"
		for lib in dependency_map[binary]:
			yaml_output += f"  - {lib}\n"
		yaml_output += "\n"

	with open(os.path.join(destFolder, 'depending-on.yaml'), 'w') as f:
		f.write(yaml_output)