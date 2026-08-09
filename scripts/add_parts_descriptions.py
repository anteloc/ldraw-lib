#!/usr/bin/env python3
"""
This script adds parts descriptions as comments to an LDraw file based on a provided TSV file containing part names and their corresponding descriptions.
Usage:
    python add_parts_descriptions.py <parts_descriptions_tsv_file> <ldraw_file | ldraw_models_dir> <ldraw_file_with_descriptions | ldraw_files_with_descriptions_dir>
The TSV file should have two columns: the first column is the part name (case-insensitive), and the second column is the description. 
Each line in the TSV file should be tab-separated."""

import os
import sys


PARTS_DESCRIPTIONS={}
COLOURS_DESCRIPTIONS={}

def cache_parts_descriptions_tsv(tsv_file_path):
    global PARTS_DESCRIPTIONS
    with open(tsv_file_path, 'r') as f:
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) >= 2:
                part_name, description =  parts[0].lower(), parts[1]
                PARTS_DESCRIPTIONS[part_name] = description

def cache_colours_descriptions(ldconfig_file_path):
    global COLOURS_DESCRIPTIONS
    with open(ldconfig_file_path, 'r') as f:
        for line in f:
            if line.startswith('0 !COLOUR'):
                parts = line.strip().split()
                if len(parts) >= 3:
                    colour_name, colour_code = parts[2].lower(), parts[4]
                    COLOURS_DESCRIPTIONS[colour_code] = colour_name

def desc_line_for(ldraw_file_line):
    global PARTS_DESCRIPTIONS
    line_items = ldraw_file_line.strip().split()

    if len(line_items) < 3:
        return None

    line_type = line_items[0]
    colour_code = line_items[1]
    part_name = line_items[-1].lower()

    if line_type == '1' and part_name in PARTS_DESCRIPTIONS:
        description = PARTS_DESCRIPTIONS[part_name]
        colour_description = COLOURS_DESCRIPTIONS.get(colour_code, colour_code)
        return f"0 // {description} ({colour_description})\n"
    
    return None

def process_ldraw_file(ldraw_file_path, output_file_path):
    with open(output_file_path, 'w') as output_file:
        with open(ldraw_file_path, 'r') as ldraw_file:
            for line in ldraw_file:
                desc_line = desc_line_for(line)
                if desc_line:
                    output_file.write(desc_line)
                output_file.write(line)

def process_ldraw_directory(ldraw_dir_path, output_dir_path):

    for root, _, files in os.walk(ldraw_dir_path):
        for file in files:
            if file.lower().endswith('.ldr') or file.lower().endswith('.mpd') or file.lower().endswith('.dat'):
                ldraw_file_path = os.path.join(root, file)
                relative_path = os.path.relpath(ldraw_file_path, ldraw_dir_path)
                output_file_path = os.path.join(output_dir_path, relative_path)
                output_file_dir = os.path.dirname(output_file_path)

                if not os.path.exists(output_file_dir):
                    os.makedirs(output_file_dir)

                process_ldraw_file(ldraw_file_path, output_file_path)

def main():
    if len(sys.argv) < 3:
        print("Usage: add_parts_descriptions.py <ldraw_file | ldraw_files_dir> <ldraw_file_with_descriptions | ldraw_files_with_descriptions_dir>")
        print("If the input is a directory, all LDraw files in that directory will be processed.")
        print("If the input is a directory, the output must be an existing directory, or one will be created, and the processed files will be saved there with the same names as the input files.")
        print("If the input is a directory and the output is a file, an error will be raised.")
        sys.exit(1)

    ldraw_src_path = sys.argv[1]
    output_dest_path = sys.argv[2]

    # TSV must reside in the upper directory relative to the script
    tsv_file_path = os.path.join(os.path.dirname(__file__), "..", "part-descriptions-full.tsv")
    # LDConfig file must reside in the ldraw/ directory, one level up from the script directory
    ldconfig_file_path = os.path.join(os.path.dirname(__file__), "..", "ldraw", "LDConfig.ldr")

    if not os.path.isfile(tsv_file_path):
        print(f"Error: File '{tsv_file_path}' does not exist.")
        sys.exit(1)

    if not os.path.exists(ldraw_src_path):
        print(f"Error: File or directory '{ldraw_src_path}' does not exist.")
        sys.exit(1)

    # Print status messages to stderr to avoid interfering with the output file
    print(f"Loading parts descriptions from '{tsv_file_path}' and colours from '{ldconfig_file_path}'...", file=sys.stderr)
    cache_parts_descriptions_tsv(tsv_file_path)
    cache_colours_descriptions(ldconfig_file_path)
    
    # Determine the output file or directory path
    input_is_directory = os.path.isdir(ldraw_src_path)
    input_is_file = os.path.isfile(ldraw_src_path)
    output_is_directory = os.path.isdir(output_dest_path)
    output_is_file = os.path.isfile(output_dest_path)

    if input_is_directory: 
        if output_is_file:
            print("Error: Output is an existing file, if the input is a directory, the output must be an existing directory or one will be created.")
            sys.exit(1)
        if not output_is_directory:
            os.makedirs(output_dest_path)
        output_dir_path = output_dest_path
        process_ldraw_directory(ldraw_src_path, output_dir_path)

    if input_is_file:
        if output_is_directory:
            output_file_path = os.path.join(output_dest_path, os.path.basename(ldraw_src_path))
            process_ldraw_file(ldraw_src_path, output_file_path)
        else:
            output_file_path = output_dest_path
            process_ldraw_file(ldraw_src_path, output_file_path)


    print(f"Finished adding parts descriptions to '{ldraw_src_path}'...", file=sys.stderr)

if __name__ == "__main__":
    main()