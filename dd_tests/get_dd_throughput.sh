#!/usr/bin/python3
# -*- coding: utf8 -*-

import argparse
import sys

def main():
    parser = argparse.ArgumentParser(prog="get_dd_throughput", description="Extracts the read and write throughput in MB/s from dd output.")
    parser.add_argument("-i")
    parser.add_argument("-o")
    args = parser.parse_args()
    
    with open(args.i, "r") as f:
    	t_out_arr = f.readlines()
    t_out_result = t_out_arr[2].split(" ")
    
    with open(args.o, "a") as g:
    	g.write("{},".format(t_out_result[-2]))

if __name__ == "__main__":
    try:
    	sys.exit(main())
    except KeyboardInterrupt:
    	pass
