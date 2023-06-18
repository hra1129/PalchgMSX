; =============================================================================
;  Palette Changer for MSX2
; -----------------------------------------------------------------------------
;  2023/June/13th  t.hara
; =============================================================================

rdslt		:= 0x000C
enaslt		:= 0x0024
romid		:= 0x002D
setwrt		:= 0x0053
ldirvm		:= 0x005C
chgmod		:= 0x005F
gtstck		:= 0x00D5
gttrig		:= 0x00D8
chgcpu		:= 0x0180
cgpnt		:= 0xF91F						; font address ( slot#(1byte), address(2bytes) )
exptbl		:= 0xFCC1
jiffy		:= 0xFC9E
vdp_port0	:= 0x98
vdp_port1	:= 0x99
vdp_port2	:= 0x9A
vdp_port3	:= 0x9B
rg0sav		:= 0xF3DF
rg1sav		:= 0xF3E0
rg2sav		:= 0xF3E1
rg3sav		:= 0xF3E2
rg4sav		:= 0xF3E3
rg5sav		:= 0xF3E4
rg6sav		:= 0xF3E5
rg7sav		:= 0xF3E6
rg8sav		:= 0xFFE7

locate		macro	vx, vy
			ld		hl, (vy << 8) | vx
			call	set_locate
			endm

print		macro	str
			ld		de, str
			call	print_de_string
			endm

			org		0x4000
			ds		"AB"					; ID
			dw		start_address			; INIT
			dw		0						; STATEMENT
			dw		0						; DEVICE
			dw		0						; TEXT
			dw		0						; RESERVED
			dw		0						; RESERVED
			dw		0						; RESERVED

; =============================================================================
;	�N������
; =============================================================================
			scope	entry
start_address::
			; MSX1 �̏ꍇ�͉������Ȃ�
			ld		a, [ romid ]			; MSX version : 0:MSX1, 1:MSX2, 2:MSX2+, 3:MSXturboR
			or		a, a
			ret		z
			; ���� ROM�̃X���b�g�ԍ��𒲂ׂ�
			call	get_this_slot
			; ���� ROM�ȍ~�ɂ����āA�ŏ��Ɍ�����J�[�g���b�W������ (������� Zf = 0)
			call	get_game_slot
			; �n�b�V�������߂�
			call	nz, get_hash
			; �n�b�V���ɑΉ�����J���[�p���b�g�Z�b�g�ԍ������߂�
			call	hash_to_palette_num
			; �J���[�p���b�g�Z�b�g�ԍ� (palette_set_num) �ɑΉ�����p���b�g���Z�b�g����
			call	update_palette_set_address
			call	update_palette
			; CPU type ���`�F�b�N����
			call	detect_cpu_type
			; [ESC]�L�[���`�F�b�N���āA������Ă���΃��j���[�֓���
			call	check_esc_key			; ESC��������Ă���� Zf = 1, ������Ă��Ȃ���� Zf = 0
			jp		z, enter_menu			; ������Ă���ꍇ�A���j���[�ցB
			; �Q�[���p�b�h1 �� B�{�^�� ���`�F�b�N���āA������Ă��Ȃ���� BIOS �֖߂�
			ld		a, 3
			call	gttrig
			or		a, a
			ret		z
		enter_menu::
			; ������
			call	initialize_menu
		main_loop:
			; �L�[����
			call	update_input
			; �J�[�\����\��
			call	show_cursor
			call	change_cpu
			call	change_palette
			; A�{�^���������ꂽ���H
			ld		a, [ press_a_button ]
			or		a, a
			jp		z, main_loop
			; �I�����ꂽ CPU���[�h�ɕύX����
			call	set_cpu_speed
			di
			; �p���b�g#0 �̈��������ɖ߂�
			ld		a, [ rg8sav ]
			out		[ vdp_port1 ], a
			ld		a, 0x80 | 8
			out		[ vdp_port1 ], a
			; �X�v���C�g�̈��������ɖ߂�
			ld		a, [ rg1sav ]
			out		[ vdp_port1 ], a
			ld		a, 0x80 | 1
			out		[ vdp_port1 ], a
			ei
			; �t�H���g�����ɖ߂�
			ld		a, 1
			call	chgmod
			ret
			endscope

; =============================================================================
;	initialize_menu
;	input:
;		none
;	output:
;		none
;	break:
;		all
; =============================================================================
			scope	initialize_menu
initialize_menu::
			; �ݒ胁�j���[�̂��߂̏�����
			ld		a, 1
			call	chgmod					; SCREEN 1
			; �X�v���C�g2�{�g��, 16x16
			ld		a, [ rg1sav ]
			or		a, 0b00000011
			di
			out		[ vdp_port1 ], a
			ld		a, 0x80 | 1
			out		[ vdp_port1 ], a
			ei
			; �p���b�g#0 ��s�����ɂ���
			ld		a, [ rg8sav ]
			or		a, 0b00100000
			di
			out		[ vdp_port1 ], a
			ld		a, 0x80 | 8
			out		[ vdp_port1 ], a
			ei
			; �t�H���g��ݒ�
			ld		hl, font_data
			ld		de, 0x0000
			ld		bc, 8 * 256
			call	ldirvm
			; �X�v���C�g��ݒ�
			ld		hl, sprite_pattern_data
			ld		de, 0x3800
			ld		bc, 32
			call	ldirvm
			ld		hl, sprite_attribute_data
			ld		de, 0x1B00
			ld		bc, 4 * 16 + 1
			call	ldirvm
			; �^�C�g����\��
			locate	7, 0
			print	s_title
			; �Q�[���J�[�g���b�W����\��
			ld		a, [ cartridge ]
			or		a, a
			jp		z, game_not_found
			locate	2, 1
			print	s_game_slot
			ld		a, [ cartridge ]
			call	print_slot_num
			locate	2, 2
			print	s_game_hash
			ld		hl, [ hash ]
			call	print_hl_hex4
		game_not_found::
			; CPU SPEED
			locate	8, 3
			print	s_cpu_speed
			xor		a, a
			ld		[ cpu_speed ], a
			call	show_cpu_speed
			; �p���b�g�ԍ�
			locate	8, 4
			print	s_palette_num
			call	show_palette_num
			ei
			; �J�[�\���̓f�t�H���g�� palette# ��I��
			ld		a, 1
			ld		[ cursor_y ], a
			ret
			endscope

; =============================================================================
;	update_input
;	input:
;		none
;	output:
;		none
;	break:
;		all
; =============================================================================
			scope	update_input
update_input::
			; �X�y�[�X�L�[�̏�Ԃ��擾����
			xor		a, a
			call	gttrig
			ld		[ press_a_button ], a
			or		a, a
			jp		nz, check_arrow_key
			inc		a
			call	gttrig
			ld		[ press_a_button ], a
			; �����L�[�̏�Ԃ��擾����
		check_arrow_key:
			xor		a, a
			call	gtstck
			push	af
			ld		a, 1
			call	gtstck
			pop		bc
			or		a, b
			ld		[ press_arrow_button ], a
			ret
			endscope

; =============================================================================
;	show_cursor
;	input:
;		none
;	output:
;		none
;	break:
;		all
; =============================================================================
			scope	show_cursor
show_cursor::
			; �J�[�\���`��
			ld		a, [ cursor_y ]
			add		a, 3
			ld		h, a
			ld		l, 7
			call	set_locate
			ld		a, [ jiffy ]
			rrca
			rrca
			rrca
			rrca
			and		a, 1
			add		a, 132				; �� or ��
			out		[ vdp_port0 ], a
			; ��܂��͉��������ꂽ�甽�]
			ld		a, [ press_arrow_button ]
			cp		a, 1
			jr		z, move_cursor
			cp		a, 5
			ret		nz
		move_cursor:
			; �J�[�\��������
			ld		a, [ cursor_y ]
			add		a, 3
			ld		h, a
			ld		l, 7
			call	set_locate
			ld		a, ' '
			out		[ vdp_port0 ], a
			; �J�[�\���L�[�����܂ő҂�
			call	wait_release_arrow
			; �ړ�����
			ld		a, [ cursor_y ]
			xor		a, 1
			ld		[ cursor_y ], a
			jp		show_cursor
			endscope

; =============================================================================
;	wait_release_arrow
;	input:
;		none
;	output:
;		none
;	break:
;		all
; =============================================================================
			scope	wait_release_arrow
wait_release_arrow::
			call	update_input
			ld		a, [ press_arrow_button ]
			or		a, a
			jr		nz, wait_release_arrow
			ret
			endscope

; =============================================================================
;	change_cpu
;	input:
;		none
;	output:
;		none
;	break:
;		all
; =============================================================================
			scope	change_cpu
change_cpu::
			; �J�[�\���ʒu�� CPU �ɖ�����Ή������Ȃ�
			ld		a, [ cursor_y ]
			or		a, a
			ret		nz
			; CPU type �� 0 �Ȃ牽�����Ȃ� ( MSX1, MSX2, Panasonic�ȊO��MSX2+ )
			ld		a, [ cpu_type ]
			cp		a, 1
			ret		c
			; CPU type �� 2 �Ȃ��p�̏�����
			jr		nz, is_turbo_r
			; Panasonic MSX2+ �̏ꍇ, 0��1�Ńg�O������
			ld		a, [ press_arrow_button ]
			cp		a, 3
			jr		z, toggle_cpu_mode
			cp		a, 7
			ret		nz
	toggle_cpu_mode:
			ld		a, [ cpu_speed ]
			xor		a, 1
			ld		[ cpu_speed ], a
			call	show_cpu_speed
			jp		wait_release_arrow
			; turboR �̏ꍇ�A0, 1, 2 �ŏz����
	is_turbo_r:
			ld		a, [ press_arrow_button ]
			cp		a, 3
			ld		b, 1
			jr		z, change_cpu_mode
			cp		a, 7
			ld		b, -1
			ret		nz
	change_cpu_mode:
			ld		a, [ cpu_speed ]
			add		a, b
			cp		a, 1
			jr		nz, skip
			add		a, b
	skip:
			cp		a, 4
			jr		c, update_cpu		; 0, 2, 3 �̏ꍇ�͖��Ȃ�
			ld		a, 0				; ���� 4 �������ꍇ�ɔ����āA�t���O��ς����� 0 �ɂ���
			jr		z, update_cpu		; 4 �������ꍇ�A0 �ɂ��čX�V��
			ld		a, 3				; 255 �������̂� 3 �ɂ���
	update_cpu:
			ld		[ cpu_speed ], a
			call	show_cpu_speed		; �\�����X�V
			jp		wait_release_arrow
			endscope

; =============================================================================
;	set_cpu_speed
;	input:
;		none
;	output:
;		none
;	break:
;		all
; =============================================================================
			scope	set_cpu_speed
set_cpu_speed::
			ld		a, [ cpu_speed ]
			or		a, a
			ret		z					; Z80-3.58MHz�ݒ� �Ȃ牽�����Ȃ�
			dec		a
			jp		z, set_5_38mhz_mode
			dec		a
			jp		z, se_r800_rom_mode
	set_r800_ram_mode:
			ld		a, 0x82
			jp		chgcpu
	se_r800_rom_mode:
			ld		a, 0x81
			jp		chgcpu
	set_5_38mhz_mode:
			xor		a, a
			out		[ 0x41 ], a
			ret
			endscope

; =============================================================================
;	change_palette
;	input:
;		none
;	output:
;		none
;	break:
;		all
; =============================================================================
			scope	change_palette
change_palette::
			; �J�[�\���ʒu�� PALETTE �ɖ�����Ή������Ȃ�
			ld		a, [ cursor_y ]
			dec		a
			ret		nz
			; ���E�Ŕԍ���ύX
			ld		a, [ press_arrow_button ]
			cp		a, 3
			ld		b, 1
			jr		z, palette_set_change
			cp		a, 7
			ld		b, -1
			ret		nz
		palette_set_change:
			ld		a, [ palette_set_num ]
			add		a, b
			and		a, 31
			ld		[ palette_set_num ], a
			; �\���X�V
			call	show_palette_num
			; �p���b�g�X�V
			call	update_palette_set_address
			call	update_palette
			jp		wait_release_arrow
			endscope

; =============================================================================
;	set_locate
;	input:
;		L .... X���W
;		H .... Y���W
;	output:
;		none
;	break:
;		AF, HL
; =============================================================================
			scope	set_locate
set_locate::
			ld		a, h					; A = 0b000YYyyy
			rrca
			rrca
			rrca							; A = 0byyy000YY
			ld		h, a					; H = 0byyy000YY
			and		a, 0b11100000			; A = 0byyy00000
			or		a, l					; L = 0b000XXXXX
			di
			out		[ vdp_port1 ], a		; set VRAM address LSB 8bit
			ld		a, h					; A = 0byyy000YY
			and		a, 0b00000011			; A = 0b000000YY
			or		a, 0b01011000			; set VRAM write bit and offset 0x1800
			out		[ vdp_port1 ], a		; set VRAM address MSB 2bit
			ei
			ret
			endscope

; =============================================================================
;	PRINT DE (ASCII-Z string)
;	input:
;		DE ... ASCII-Z������
;	output:
;		DE ... �w�肳�ꂽ������̍Ō�� 0 �������A�h���X
;	break:
;		AF, DE
; =============================================================================
			scope	print_de_string
print_de_string::
			ld		a, [de]
			or		a, a
			ret		z
			out		[ vdp_port0 ], a
			inc		de
			jr		print_de_string
			endscope

; =============================================================================
;	PRINT HL (HEX number)
;	input:
;		HL ... �\�����鐔�l
;	output:
;		none
;	break:
;		AF, HL
; =============================================================================
			scope	print_hl_hex
print_hl_hex4::
			ld		a, h
			rrca
			rrca
			rrca
			rrca
			call	put_hex_one
			ld		a, h
			call	put_hex_one
print_hl_hex2::
			ld		a, l
			rrca
			rrca
			rrca
			rrca
			call	put_hex_one
			ld		a, l
put_hex_one::
			and		a, 0x0F
			add		a, '0'
			cp		a, '9' + 1
			jr		c, skip
			add		a, 'A' - ('9' + 1)
		skip:
			out		[ vdp_port0 ], a
			ret
			endscope

; =============================================================================
;	detect_cpu_type
;	input:
;		none
;	output:
;		none
;	break:
;		all
; =============================================================================
			scope	detect_cpu_type
detect_cpu_type::
			ld		a, [ romid ]
			cp		a, 2					; MSX1 or MSX2 ?
			jp		c, is_msx1_or_msx2
			cp		a, 3					; MSXturboR ?
			jp		nc, is_msx_turbo_r
			; �p�i�� MSX2+ ���ǂ����`�F�b�N
			in		a, [ 0x40 ]
			cpl
			ld		b, a					; B�Ƀo�b�N�A�b�v
			ld		a, 8					; Panasonic���[�J�[ID
			out		[ 0x40 ], a
			in		a, [ 0x40 ]
			cpl
			cp		a, 8					; Panasonic���[�J�[ID���󗝂��ꂽ�H
			jr		nz, is_normal_msx2p		; -- �󗝂���Ȃ������ꍇ�A���̃��[�J�[��MSX2+�Ȃ̂ŁAZ80-3.58MHz�Œ�B
	is_panasonic_msx2p:
			ld		a, 1
			ld		[ cpu_type ], a
			ret
	is_normal_msx2p:
			ld		a, b
			out		[ 0x40 ], a
	is_msx1_or_msx2:
			xor		a, a
			ld		[ cpu_type ], a
			ret
	is_msx_turbo_r:
			ld		a, 2
			ld		[ cpu_type ], a
			ret
			endscope

; =============================================================================
;	show_cpu_speed
;	input:
;		cpu_speed ... �\�����郂�[�h
;	output:
;		none
;	break:
;		all
; =============================================================================
			scope	show_cpu_speed
show_cpu_speed::
			locate	12, 3
			ld		a, [ cpu_speed ]
			add		a, a
			ld		l, a
			ld		h, 0
			ld		de, ps_cpu_mode
			add		hl, de
			ld		e, [hl]
			inc		hl
			ld		d, [hl]
			jp		print_de_string
	ps_cpu_mode:
			dw		s_cpu_mode0
			dw		s_cpu_mode1
			dw		s_cpu_mode2
			dw		s_cpu_mode3
	s_cpu_mode0:
			ds		"Z80-3.58MHz      "
			db		0
	s_cpu_mode1:
			ds		"Z80-5.38MHz      "
			db		0
	s_cpu_mode2:
			ds		"R800-7.16MHz(ROM)"
			db		0
	s_cpu_mode3:
			ds		"R800-7.16MHz(RAM)"
			db		0
			endscope

; =============================================================================
;	�p���b�g�ԍ���\������
;	input:
;		[palette_set_num] ... �p���b�g�ԍ�
;	output:
;		none
;	break:
;		AF, DE, L
; =============================================================================
			scope	show_palette_num
show_palette_num::
			locate	17, 4
			ld		a, [ palette_set_num ]
			ld		l, a
			jp		print_hl_hex2
			endscope

; =============================================================================
;	PRINT A (SLOT#)
;	input:
;		A ... �\������X���b�g�ԍ�
;	output:
;		none
;	break:
;		AF, DE, L
; =============================================================================
			scope	print_slot_num
print_slot_num::
			ld		l, a
			and		a, 0b00000011			; primary slot number
			call	put_hex_one
			ld		a, l
			or		a, a
			ret		p						; �g���X���b�g�łȂ���΂����Ŗ߂�
			ld		a, '-'
			out		[ vdp_port0 ], a
			ld		a, l
			rrca
			rrca
			and		a, 0b00000011			; extended slot number
			jp		put_hex_one
			endscope

; =============================================================================
;	����ROM�̃X���b�g�����o����
; =============================================================================
			scope	get_this_slot
get_this_slot::
			; ��{�X���b�g���擾����
			di								; �X�^�b�N�̂��� page3 ��؂�ւ���̂Ŋ��荞�݋֎~
			in		a, [ 0xA8 ]				; PPI port.A (Primary Slot Register)
			ld		c, a					; backup Primary Slot Register
			and		a, 0b00001100			; page1
			ld		b, a
			rlca
			rlca
			rlca
			rlca
			or		a, b					; 0bSS00SS00
			ld		b, a
			ld		a, c
			and		a, 0b00110011
			or		a, b					; 0bSSssSSss : ss �͌��݂̐ݒ���ێ�
			out		[ 0xA8 ], a				; page3 �� page1 �Ɠ����X���b�g�ɂ���
			; �g���X���b�g�̗L���𒲂ׂ�
			ld		hl, 0xFFFF
			ld		a, [ hl ]				; �g���X���b�g���W�X�^
			cpl
			ld		b, a					; �g���X���b�g���W�X�^(��������Ȃ�)�̒l���o�b�N�A�b�v
			ld		[ hl ], a				; �g���X���b�g���W�X�^�ł���Δ��]����̂ŁA���]�����l����������ł݂�
			cpl
			cp		a, [ hl ]				; ��v���邩�m�F : ROM/RAM �▢�ڑ��Ȃ甽�]���Ȃ��̂ŕs��v����
			ld		a, 0					; �t���O��ς����� A �� 0 ���Z�b�g
			jr		z, not_extended			; �s��v�Ȃ�g���X���b�g�͑��݂��Ȃ��̂Ŋ�{�X���b�g������
			; �g���X���b�g�������ꍇ
			ld		a, b					; �g���X���b�g���W�X�^�̒l
			and		a, 0b00001100			; page1 �̊g���X���b�g�ԍ�
			or		a, 0x80					; 0b1000EE00 : EE �Ɋg���X���b�g�ԍ�
			; ��{�X���b�g�̏���
	not_extended:
			ld		b, a					; �g���X���b�g�ԍ����o�b�N�A�b�v
			ld		a, c					; ��{�X���b�g�ԍ��𕜌�
			rrca
			rrca
			and		a, 0b00000011
			or		a, b					; 0b1000EEPP �� 0b000000PP �̂ǂ��炩�ɂȂ�
			ld		b, a					; ���߂��X���b�g�ԍ��� B���W�X�^�ցB
			; ��{�X���b�g�����ɖ߂�
			ld		a, c
			out		[ 0xA8 ], a
			; �������� page3 �� RAM �ɖ߂�
			ei
			ld		a, b
			ld		[ rom_slot ], a			; ���߂��X���b�g�ԍ��� rom_slot �փZ�[�u�B
			ret
			endscope

; =============================================================================
;	�Q�[���J�[�g���b�W�̃X���b�g������
; =============================================================================
			scope	get_game_slot
get_game_slot::
			; �܂��́A�Q�[���J�[�g���b�W�͌�����Ȃ������}�[�N��t���Ă���
			xor		a, a
			ld		[ cartridge ], a		; 0x00 ���Ɓu������Ȃ������v�Ƃ����Ӗ�
			; �T���J�n�� ����ROM �̃X���b�g�̎�����B
			ld		a, [ rom_slot ]
			ld		b, a
			and		a, 0b00000011			; ����ROM�̊�{�X���b�g�ԍ�
			add		a, exptbl & 255			; exptbl �̑Ώۗ̈�����߂�
			ld		l, a
			ld		h, exptbl >> 8			; HL = exptbl[ primary_slot(rom_slot) ]
			ld		a, b
			jp		go_next_slot

	slot_loop:
			push	hl
			push	af
			ld		hl, 0x4000
			call	rdslt					; slot#A �� 4000�Ԓn��ǂ�
			ld		[signature + 0], a
			pop		af
			push	af
			inc		hl
			call	rdslt					; slot#A �� 4001�Ԓn��ǂ�
			ld		[signature + 1], a
			pop		af
			; �ǂݎ���� signature �� "AB" ���H
			ld		hl, [signature]
			ld		de, 'A' + ('B' << 8)
			or		a, a
			sbc		hl, de
			pop		hl
			jp		z, detect_cartridge
			; "AB" ����Ȃ������̂ŁA���̃X���b�g�B
	go_next_slot:
			or		a, a
			jp		p, go_next_primary_slot
			; ���̊g���X���b�g
	go_next_extend_slot:
			add		a, 0b00000100
			bit		4, a					; slot#?-4 �ɂȂ����H
			jp		z, slot_loop			; -- �Ȃ��Ă��Ȃ��ꍇ�́A�܂�������{�X���b�g�̎��̊g���X���b�g��T��
			; ���̊�{�X���b�g
	go_next_primary_slot:
			and		a, 0b00000011
			add		a, 0b00000001
			cp		a, 4					; slot#4-0 �ɂȂ����H
			ret		z						; -- slot#4-0 �ɂȂ����B�܂�A�J�[�g���b�W������Ȃ������B
			ld		b, a
			inc		hl
			; ���̊�{�X���b�g�͊g������Ă��邩�H
			ld		a, [ hl ]				; A = exptbl[ primary_slot(A) ]
			and		a, 0b10000000
			or		a, b
			jp		slot_loop
	detect_cartridge:
			ld		[ cartridge ], a
			or		a, a					; Zf = 0
			ret
			endscope

; =============================================================================
;	�Q�[���J�[�g���b�W�� hash�l�����߂�
;	���� ROM �� page1 �ɂ���A�Q�[���J�[�g���b�W�� page1 �ɂ���̂ŁA
;	�n�b�V���v�Z���[�`���� page3 �փR�s�[���Ă����Ŏ��s����
; =============================================================================
			scope	get_hash
get_hash::
			; ROM��ɂ��� get_hash_sub �� page3 �� DRAM �̏���̈ʒu�փR�s�[
			ld		hl, get_hash_sub_on_rom
			ld		de, get_hash_sub
			ld		bc, get_hash_sub_end - get_hash_sub
			ldir
			; �R�s�[�����R�[�h���Ăяo��
			jp		get_hash_sub
			endscope

; =============================================================================
;	page1 ���Q�[���J�[�g���b�W�̃X���b�g�ɐ؂�ւ��� hash ���v�Z���Ă���
;	page1 ������ROM�ɖ߂�
; =============================================================================
get_hash_sub_on_rom::
			org		hash_sub
			scope	get_hash_sub
get_hash_sub::
			; page1 ���Q�[���J�[�g���b�W�ɐ؂�ւ���
			ld		a, [ cartridge ]
			ld		h, 0x40
			call	enaslt
			; hash�����߂�
			ld		hl, 0x4000
			ld		de, 0x1234
			ld		bc, 0x4000
		loop:
			; ����byte
			ld		a, [hl]
			inc		hl
			inc		a
			xor		a, e
			add		a, 3
			ld		e, a
			; �byte
			ld		a, [hl]
			inc		hl
			adc		a, 7
			xor		a, d
			dec		a
			ld		d, a
			; ���[�v�I��肩�H
			dec		bc
			ld		a, c
			or		a, b
			jp		nz, loop
			; ���߂� hash ��ۑ�
			ld		[ hash ], de
			; �X���b�g�����ɖ߂�
			ld		a, [ rom_slot ]
			ld		h, 0x40
			call	enaslt
			ret
get_hash_sub_end::
			endscope

			org		get_hash_sub_on_rom + (get_hash_sub_end - get_hash_sub)

; =============================================================================
;	[ESC]�L�[��������Ă��邩�m�F����
; =============================================================================
			scope	check_esc_key
check_esc_key::
			di
			in		a, [ 0xAA ]			; PPI port B
			and		a, 0b11110000
			or		a, 7				; MSX�L�[�}�g���N�X �s7 (bit2 �� ESC �ɑΉ��B������Ă�� 0)
			out		[ 0xAA ], a			; PPI port B : �L�[�}�g���N�X �s7 ��I������
			nop
			in		a, [ 0xA9 ]			; MSX�L�[�}�g���N�X
			ei
			and		a, 0b00000100		; ESC�L�[�𒊏o�B������Ă�� 0 �ɂȂ�̂� Zf = 1, ������Ă��Ȃ���� Zf = 0
			ret
			endscope

; =============================================================================
;	hash�l�ɑΉ����� palette_set_num �����߂�
; =============================================================================
			scope	hash_to_palette_num
hash_to_palette_num::
			ld		bc, [ hash ]
			ld		hl, hash_table
		loop:
			; hash_table�z��̌��݂̎Q�Ɨv�f�� hash�l�� DE �ɁApalette_set_num�� A �Ɋi�[
			ld		e, [hl]
			inc		hl
			ld		d, [hl]
			inc		hl
			ld		a, [hl]
			inc		hl
			; �ԕ�(palette_set_num = 0xFF)���H
			inc		a					; �ԕ��Ȃ炱���� 0x00 �ɂȂ�
			jr		z, not_found
			dec		a					; inc a ���L�����Z�����Ė߂�
			; DE �� BC ���r����
			ex		de, hl
			or		a, a
			sbc		hl, bc
			ex		de, hl
			jr		nz, loop
			; hash_table �ɊY����������Ȃ������ꍇ�́A�����I�� palette_set_num = 0 �ɂ���
			; hash_table �ɊY�������������ꍇ�́Apalette_set_num = hash_table ����������l�ɂ���
		not_found:
			ld		[ palette_set_num ], a
			ret
			endscope

; =============================================================================
;	palette_set_num �ɑΉ����� palette_set �̃A�h���X�����߂�
; =============================================================================
			scope	update_palette_set_address
update_palette_set_address::
			; �A�h���X�v�Z
			ld		a, [ palette_set_num ]
			ld		l, a
			ld		h, 0
			add		hl, hl
			add		hl, hl
			add		hl, hl
			add		hl, hl
			add		hl, hl
			ld		de, palette_set_array
			add		hl, de					; HL = palette_set_array + [palette_set_num] * 32
			; ���߂��A�h���X��ϐ��ɕۑ�
			ld		[ palette_set_address ], hl
			ret
			endscope

; =============================================================================
;	palette_set_address �ɕۑ�����Ă�A�h���X�ɂ���p���b�g�l�Ɋ�Â���
;	�J���[�p���b�g��ύX����
; =============================================================================
			scope	update_palette
update_palette::
			; VDP R#16 = 0 : palette index = 0
			di
			xor		a, a
			out		[ vdp_port1 ], a
			ld		a, 0x80 | 16
			out		[ vdp_port1 ], a
			ei
			; 16 palette (32byte) �ݒ肷��
			ld		hl, [ palette_set_address ]
			ld		bc, (32 << 8) | vdp_port2
			otir
			ret
			endscope

; =============================================================================
;	�t�H���g�f�[�^
; =============================================================================
font_data::
			include	"font.asm"

; =============================================================================
;	�X�v���C�g�f�[�^
;	16�h�b�g x 16�h�b�g 2�{�g��X�v���C�g�� 4x4 �ŕ��ׂ�
;	1����32�h�b�g�A4�� 128�h�b�g�Ȃ̂ŁA���ɃZ���^�����O 64�h�b�g
; =============================================================================
sprite_pattern_data::
			db		0b01111111
			db		0b11111111
			db		0b11111111
			db		0b11111111
			db		0b11111111
			db		0b11111111
			db		0b11111111
			db		0b11111111

			db		0b11111111
			db		0b11111111
			db		0b11111111
			db		0b11111111
			db		0b11111111
			db		0b11111111
			db		0b01111111
			db		0b00000000

			db		0b11111100
			db		0b11111110
			db		0b11111110
			db		0b11111110
			db		0b11111110
			db		0b11111110
			db		0b11111110
			db		0b11111110

			db		0b11111110
			db		0b11111110
			db		0b11111110
			db		0b11111110
			db		0b11111110
			db		0b11111110
			db		0b11111100
			db		0b00000000

sprite_attribute_data::
;			  		Y          , X          , pat, color
			db		63 + 32 * 0, 64 + 32 * 0, 0  , 0
			db		63 + 32 * 0, 64 + 32 * 1, 0  , 1
			db		63 + 32 * 0, 64 + 32 * 2, 0  , 2
			db		63 + 32 * 0, 64 + 32 * 3, 0  , 3

			db		63 + 32 * 1, 64 + 32 * 0, 0  , 4
			db		63 + 32 * 1, 64 + 32 * 1, 0  , 5
			db		63 + 32 * 1, 64 + 32 * 2, 0  , 6
			db		63 + 32 * 1, 64 + 32 * 3, 0  , 7

			db		63 + 32 * 2, 64 + 32 * 0, 0  , 8
			db		63 + 32 * 2, 64 + 32 * 1, 0  , 9
			db		63 + 32 * 2, 64 + 32 * 2, 0  , 10
			db		63 + 32 * 2, 64 + 32 * 3, 0  , 11

			db		63 + 32 * 3, 64 + 32 * 0, 0  , 12
			db		63 + 32 * 3, 64 + 32 * 1, 0  , 13
			db		63 + 32 * 3, 64 + 32 * 2, 0  , 14
			db		63 + 32 * 3, 64 + 32 * 3, 0  , 15

			db		208

; =============================================================================
;	������
; =============================================================================
s_title::
			ds		"<PALETTE CHANGER>"
			db		0
s_game_slot::
			ds		"GAME CARTRIDGE SLOT #"
			db		0
s_game_hash::
			ds		"GAME CARTRIDGE HASH 0x"
			db		0
s_cpu_speed::
			ds		"CPU:"
			ds		0
s_palette_num::
			ds		"PALETTE#:"
			ds		0

; =============================================================================
;	�J���[�p���b�g�Z�b�g�i32�Z�b�g�j
; =============================================================================
palette		macro	vr, vg, vb
			db		(vb & 7) | ((vr & 7) << 4)
			db		(vg & 7)
			endm

palette_set_array::
			include	"palette00.asm"
			include	"palette01.asm"
			include	"palette02.asm"
			include	"palette03.asm"
			include	"palette04.asm"
			include	"palette05.asm"
			include	"palette06.asm"
			include	"palette07.asm"
			include	"palette08.asm"
			include	"palette09.asm"
			include	"palette10.asm"
			include	"palette11.asm"
			include	"palette12.asm"
			include	"palette13.asm"
			include	"palette14.asm"
			include	"palette15.asm"
			include	"palette16.asm"
			include	"palette17.asm"
			include	"palette18.asm"
			include	"palette19.asm"
			include	"palette20.asm"
			include	"palette21.asm"
			include	"palette22.asm"
			include	"palette23.asm"
			include	"palette24.asm"
			include	"palette25.asm"
			include	"palette26.asm"
			include	"palette27.asm"
			include	"palette28.asm"
			include	"palette29.asm"
			include	"palette30.asm"
			include	"palette31.asm"

; =============================================================================
;	hash�l�ƃp���b�g�Z�b�g�̑Ή��\
; =============================================================================
hash_entry	macro	vhash, vpalette_set_num
			dw		vhash
			db		vpalette_set_num
			endm

			include	"hash_to_palette.asm"

; =============================================================================
;	���[�N�G���A
; =============================================================================

rom_slot			:= 0xC000						; 1byte  : ����ROM����������Ă���X���b�g�̃X���b�g�ԍ�
signature			:= rom_slot + 1					; 2bytes : �Q�[���J�[�g���b�W�̒T�����̃��[�N�G���A
cartridge			:= signature + 2				; 1byte  : �Q�[���J�[�g���b�W�̃X���b�g�ԍ��A������Ȃ��ꍇ�� 0x00
palette_set_address	:= cartridge + 1				; 2bytes : �I�������p���b�g�Z�b�g�̃A�h���X
cpu_speed			:= palette_set_address + 2		; 1byte  : CPU�X�s�[�h: 0=Z80-3.58MHz, 1=Z80-5.37MHz, 2=R800-ROM, 3=R800-RAM
cpu_type			:= cpu_speed + 1				; 1byte  : CPU���: 0=Normal, 1=Panasonic MSX2+, 2=MSXturboR
cursor_y			:= cpu_type + 1					; 1byte  : �J�[�\��Y���W: 0=CPU SPEED, 1=PALETTE
press_a_button		:= cursor_y + 1					; 1byte  : A�{�^���̏��: 0=���, 0xFF=����
press_arrow_button	:= press_a_button + 1			; 1byte  : �����L�[
hash				:= press_arrow_button + 1		; 2bytes : �Q�[���J�[�g���b�W�̃n�b�V���l
palette_set_num		:= hash + 2						; 1byte  : �I�𒆂̃p���b�g�Z�b�g�ԍ�
hash_sub			:= palette_set_num + 1			; hash_sub_size bytes: �n�b�V���v�Z���[�`���u����
