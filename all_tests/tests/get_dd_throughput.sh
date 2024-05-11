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
    print(t_out_arr)
    t_out_result = t_out_arr[2].split(" ")
    
    with open(args.o, "a") as g:
        res = int(t_out_result[-2])
        unit = t_out_result[-1][:2]
        sec = t_out_result[-4]
        if unit == "GB":
            res *= 1000
        else if unit == "KB":
            res /= 1000
    	g.write("{}:{},".format(res, sec))

if __name__ == "__main__":
    try:
    	sys.exit(main())
    except KeyboardInterrupt:
    	pass
