; =============================================================================
;  Palette Changer for MSX2
; -----------------------------------------------------------------------------
;  2023/June/13th  t.hara
; =============================================================================

rdslt		:= 0x000C
enaslt		:= 0x0024
romid		:= 0x002D
exptbl		:= 0xFCC1

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
			; �n�b�V���ɑΉ�����J���[�p���b�g���Z�b�g����
			
			; [ESC]�L�[���`�F�b�N���āA������Ă��Ȃ���� BIOS �֖߂�
			
			; �ݒ胁�j���[
			
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
;	���[�N�G���A
; =============================================================================

rom_slot	:= 0xC000						; 1byte  : ����ROM����������Ă���X���b�g�̃X���b�g�ԍ�
signature	:= rom_slot + 1					; 2bytes : �Q�[���J�[�g���b�W�̒T�����̃��[�N�G���A
cartridge	:= signature + 2				; 1byte  : �Q�[���J�[�g���b�W�̃X���b�g�ԍ��A������Ȃ��ꍇ�� 0x00
hash		:= cartridge + 1				; 2bytes : �Q�[���J�[�g���b�W�̃n�b�V���l
hash_sub	:= hash + 2						; hash_sub_size bytes: �n�b�V���v�Z���[�`���u����
