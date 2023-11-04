#!/usr/bin/python3
# -*- coding: utf8 -*-

import argparse
import sys

def main():
    parser = argparse.ArgumentParser(prog="get_hdparm_read", description="Extracts the cached and buffered throughput in MB/s from hdparm output.")
    parser.add_argument("-i")
    parser.add_argument("-c")
    parser.add_argument("-b")
    args = parser.parse_args()
    
    with open(args.i, "r") as f:
    	t_out_arr = f.readlines()
    t_out_cached = t_out_arr[2].split(" ")
    t_out_buffered = t_out_arr[3].split(" ")
    
    with open(args.c, "a") as g:
    	g.write("{},".format(t_out_cached[-2]))
    
    with open(args.b, "a") as h:
    	h.write("{},".format(t_out_buffered[-2]))

if __name__ == "__main__":
    try:
    	sys.exit(main())
    except KeyboardInterrupt:
    	pass
