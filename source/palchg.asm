; =============================================================================
;  Palette Changer for MSX2
; -----------------------------------------------------------------------------
;  2023/June/13th  t.hara
; =============================================================================

rdslt		:= 0x000C
enaslt		:= 0x0024
romid		:= 0x002D
exptbl		:= 0xFCC1
vdp_port0	:= 0x98
vdp_port1	:= 0x99
vdp_port2	:= 0x9A
vdp_port3	:= 0x9B

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
			; [ESC]�L�[���`�F�b�N���āA������Ă��Ȃ���� BIOS �֖߂�
			call	check_esc_key			; ESC��������Ă���� Zf = 1, ������Ă��Ȃ���� Zf = 0
			ret		nz						; ������Ă��Ȃ��ꍇ�ABIOS�֖߂�
			; �ݒ胁�j���[
			ret								; ���܂�����ĂȂ�
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

			org		get_hash_sub_on_rom + (get_hash_sub - hash_sub)

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
			ld		[ vdp_port1 ], a
			ld		a, 0x80 | 16
			ld		[ vdp_port1 ], a
			ei
			; 16 palette (32byte) �ݒ肷��
			ld		hl, [ palette_set_address ]
			ld		bc, (32 << 8) | vdp_port3
			otir
			ret
			endscope

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
hash				:= palette_set_address + 2		; 2bytes : �Q�[���J�[�g���b�W�̃n�b�V���l
palette_set_num		:= hash + 2						; 1byte  : �I�𒆂̃p���b�g�Z�b�g�ԍ�
hash_sub			:= hash + 2						; hash_sub_size bytes: �n�b�V���v�Z���[�`���u����
