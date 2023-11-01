import csv


def iozone_dict():
	"""Converts a csv containing iozone results to a dictionary."""
	with open("iozone.csv","r") as f:
		io_results = csv.reader(f)
	
		header = []
		header = next(io_results)
		data = dict.fromkeys(header)
		
		for h in data.keys():
			data[h] = []
		
		while 1:
			row = []
			try:
				row = next(io_results)
			except (AttributeError, StopIteration):
				break
			
			for i, v in enumerate(row):
				data[header[i]].append(row[i])

