#!/usr/bin/env python3
# coding=utf-8
# =============================================================================
#  Parts converter
# -----------------------------------------------------------------------------
#  2023/June/17th t.hara
# =============================================================================

import sys
import re

try:
	from PIL import Image
except:
	print( "ERROR: Require PIL module. Please run 'pip3 install Pillow.'" )
	exit()

# --------------------------------------------------------------------
def my_rgb( r, g, b ):
	return (r << 16) | (g << 8) | b;

# --------------------------------------------------------------------
color_palette = [
	my_rgb(   0,   0,   0 ),
	my_rgb(   0,   0,   0 ),
	my_rgb( 101, 206,  51 ),
	my_rgb( 141, 255,  75 ),
	my_rgb(  60,  93, 207 ),
	my_rgb( 135, 123, 255 ),
	my_rgb( 183, 114,   0 ),
	my_rgb(  30, 192, 243 ),
	my_rgb( 186, 126,  60 ),
	my_rgb( 228, 159, 120 ),
	my_rgb( 204, 186,  60 ),
	my_rgb( 231, 231, 111 ),
	my_rgb(  96, 165,   0 ),
	my_rgb( 183, 105, 255 ),
	my_rgb( 180, 183, 180 ),
	my_rgb( 255, 255, 255 ),
];

# --------------------------------------------------------------------
def get_color_index( r, g, b ):
	c = my_rgb( r, g, b )
	try:
		i = color_palette.index( c )
	except:
		return -1
	if i == 0:
		i = 1
	return i

# --------------------------------------------------------------------
def put_datas( file, datas ):
	index = 0
	pattern_no = 0
	for d in datas:
		if index == 0:
			file.write( "\tdb\t" )
		if index == 7:
			file.write( "0x%02X\t\t; #%02X\n" % ( d, pattern_no ) )
			pattern_no = pattern_no + 1
		else:
			file.write( "0x%02X, " % d )
		index = (index + 1) & 7

# --------------------------------------------------------------------
def get_source_xy_for_boss_parts( pt ):
	boss_y = 152

	x = (pt % 32) * 8
	y = (pt >> 5) * 8 + boss_y
	return ( x, y )

# --------------------------------------------------------------------
def convert_pcg( img, c ):
	one_pattern_generate_table = []
	one_color_table = []
	py = int(c / 16) * 8
	px = (c % 16) * 8
	for y in range( 0, 8 ):
		# 色を拾ってくる ---------------------------
		palette = [ 0, 0 ]
		color_list = []
		for x in range( 0, 8 ):
			( r, g, b ) = img.getpixel( ( px + x, py + y ) )
			color_index = get_color_index( r, g, b )
			if color_index == -1:
				print( "[ERROR] Invalid color on ( %d, %d )" % ( px + x, py + y ) )
				exit(1)
			if color_index in color_list:
				continue
			color_list.append( color_index )
		if len( color_list ) == 1:
			if color_list[0] == 0:
				palette[0] = 1
				palette[1] = 1
			else:
				palette[0] = 1
				palette[1] = color_list[0]
		elif len( color_list ) == 2:
			if color_list[0] < color_list[1]:
				palette[0] = color_list[0]
				palette[1] = color_list[1]
			else:
				palette[0] = color_list[1]
				palette[1] = color_list[0]
		else:
			print( "[ERROR] Too many colors ( %d-%d, %d ) on PCG#%d:%d" % ( px, px + 7, py + y, c, (py + y) % 8 ) )
			exit(1)
		# 確定した2色に基づいてパターンを形成する ------------
		pattern = 0
		for x in range( 0, 8 ):
			( r, g, b ) = img.getpixel( ( px + x, py + y ) )
			color_index = get_color_index( r, g, b )
			pattern = (pattern << 1) | palette.index( color_index )
		one_pattern_generate_table.append( pattern )
		# 確定した2色に基づいてカラーパターンを形成する ------
		color = palette[0] | (palette[1] << 4)
		one_color_table.append( color )
	return ( one_pattern_generate_table, one_color_table )

# --------------------------------------------------------------------
def convert( input_name, output_name ):

	try:
		img = Image.open( input_name )
	except:
		print( "ERROR: Cannot read the '%s'." % input_name )
		return

	img = img.convert( 'RGB' )

	# PCGの変換 ----------------------------------------
	pattern_generate_table = []
	color_table = []
	for c in range( 0, 256 ):
		( one_pattern_generate_table, one_color_table ) = convert_pcg( img, c )
		pattern_generate_table.extend( one_pattern_generate_table )
		color_table.extend( one_color_table )

	with open( "%s.asm" % output_name, 'wt' ) as file:
		file.write( '; ====================================================================\n' )
		file.write( ';  FONT DATA CONVERTER\n' )
		file.write( '; --------------------------------------------------------------------\n' )
		file.write( ';  Copyright (C)2023 t.hara (HRA!)\n' )
		file.write( '; ====================================================================\n' )
		file.write( '\n' )
		put_datas( file, pattern_generate_table )
	print( "Success!!" )

# --------------------------------------------------------------------
def usage():
	print( "Usage> parts_converter.py <image_file>" )

# --------------------------------------------------------------------
def main():
	if len( sys.argv ) < 2:
		usage()
		exit()
	output_name = re.sub( r'^.*/', r'', sys.argv[1] )
	output_name = re.sub( r'^(.*)\..*?$', r'\1', output_name )
	print( "Input  name: %s" % sys.argv[1] )
	print( "Output name: %s.asm" % output_name )
	convert( sys.argv[1], output_name )

if __name__ == "__main__":
	main()
