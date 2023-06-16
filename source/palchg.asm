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
cgpnt		:= 0xF91F						; font address ( slot#(1byte), address(2bytes) )
exptbl		:= 0xFCC1
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
;	起動処理
; =============================================================================
			scope	entry
start_address::
			; MSX1 の場合は何もしない
			ld		a, [ romid ]			; MSX version : 0:MSX1, 1:MSX2, 2:MSX2+, 3:MSXturboR
			or		a, a
			ret		z
			; この ROMのスロット番号を調べる
			call	get_this_slot
			; この ROM以降にあって、最初に見つかるカートリッジを検索 (見つかれば Zf = 0)
			call	get_game_slot
			; ハッシュを求める
			call	nz, get_hash
			; ハッシュに対応するカラーパレットセット番号を求める
			call	hash_to_palette_num
			; カラーパレットセット番号 (palette_set_num) に対応するパレットをセットする
			call	update_palette_set_address
			call	update_palette
			; [ESC]キーをチェックして、押されていればメニューへ入る
			call	check_esc_key			; ESCが押されていれば Zf = 1, 押されていなければ Zf = 0
			jp		z, enter_menu			; 押されている場合、メニューへ。
			; ゲームパッド1 の Bボタン をチェックして、押されていなければ BIOS へ戻る
			ld		a, 3
			call	gttrig
			or		a, a
			ret		z
		enter_menu::
			; 設定メニューのための初期化
			ld		a, 1
			call	chgmod					; SCREEN 1
			; スプライト2倍拡大, 16x16
			ld		a, [ rg1sav ]
			or		a, 0b00000011
			di
			out		[ vdp_port1 ], a
			ld		a, 0x80 | 1
			out		[ vdp_port1 ], a
			ei
			; パレット#0 を不透明にする
			ld		a, [ rg8sav ]
			or		a, 0b00100000
			di
			out		[ vdp_port1 ], a
			ld		a, 0x80 | 8
			out		[ vdp_port1 ], a
			ei
			; フォントを設定
			ld		hl, font_data
			ld		de, 0x0000
			ld		bc, 8 * 256
			call	ldirvm
			; スプライトを設定
			ld		hl, sprite_pattern_data
			ld		de, 0x3800
			ld		bc, 32
			call	ldirvm
			ld		hl, sprite_attribute_data
			ld		de, 0x1B00
			ld		bc, 4 * 16 + 1
			call	ldirvm
			; 文字を表示
			locate	7, 0
			print	s_title
		st:
			jp		st
			ret								; ★まだ作ってない
			endscope

; =============================================================================
;	set_locate
;	input:
;		L .... X座標
;		H .... Y座標
;	output:
;		なし
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
;		DE ... ASCII-Z文字列
;	output:
;		DE ... 指定された文字列の最後の 0 を示すアドレス
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
;	このROMのスロットを検出する
; =============================================================================
			scope	get_this_slot
get_this_slot::
			; 基本スロットを取得する
			di								; スタックのある page3 を切り替えるので割り込み禁止
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
			or		a, b					; 0bSSssSSss : ss は現在の設定を維持
			out		[ 0xA8 ], a				; page3 を page1 と同じスロットにする
			; 拡張スロットの有無を調べる
			ld		hl, 0xFFFF
			ld		a, [ hl ]				; 拡張スロットレジスタ
			cpl
			ld		b, a					; 拡張スロットレジスタ(かもしれない)の値をバックアップ
			ld		[ hl ], a				; 拡張スロットレジスタであれば反転するので、反転した値を書き込んでみる
			cpl
			cp		a, [ hl ]				; 一致するか確認 : ROM/RAM や未接続なら反転しないので不一致する
			ld		a, 0					; フラグを変えずに A に 0 をセット
			jr		z, not_extended			; 不一致なら拡張スロットは存在しないので基本スロット処理へ
			; 拡張スロットだった場合
			ld		a, b					; 拡張スロットレジスタの値
			and		a, 0b00001100			; page1 の拡張スロット番号
			or		a, 0x80					; 0b1000EE00 : EE に拡張スロット番号
			; 基本スロットの処理
	not_extended:
			ld		b, a					; 拡張スロット番号をバックアップ
			ld		a, c					; 基本スロット番号を復元
			rrca
			rrca
			and		a, 0b00000011
			or		a, b					; 0b1000EEPP か 0b000000PP のどちらかになる
			ld		b, a					; 求めたスロット番号は Bレジスタへ。
			; 基本スロットを元に戻す
			ld		a, c
			out		[ 0xA8 ], a
			; ここから page3 が RAM に戻る
			ei
			ld		a, b
			ld		[ rom_slot ], a			; 求めたスロット番号を rom_slot へセーブ。
			ret
			endscope

; =============================================================================
;	ゲームカートリッジのスロットを検索
; =============================================================================
			scope	get_game_slot
get_game_slot::
			; まずは、ゲームカートリッジは見つからなかったマークを付けておく
			xor		a, a
			ld		[ cartridge ], a		; 0x00 だと「見つからなかった」という意味
			; 探索開始は このROM のスロットの次から。
			ld		a, [ rom_slot ]
			ld		b, a
			and		a, 0b00000011			; このROMの基本スロット番号
			add		a, exptbl & 255			; exptbl の対象領域を求める
			ld		l, a
			ld		h, exptbl >> 8			; HL = exptbl[ primary_slot(rom_slot) ]
			ld		a, b
			jp		go_next_slot

	slot_loop:
			push	hl
			push	af
			ld		hl, 0x4000
			call	rdslt					; slot#A の 4000番地を読む
			ld		[signature + 0], a
			pop		af
			push	af
			inc		hl
			call	rdslt					; slot#A の 4001番地を読む
			ld		[signature + 1], a
			pop		af
			; 読み取った signature は "AB" か？
			ld		hl, [signature]
			ld		de, 'A' + ('B' << 8)
			or		a, a
			sbc		hl, de
			pop		hl
			jp		z, detect_cartridge
			; "AB" じゃなかったので、次のスロット。
	go_next_slot:
			or		a, a
			jp		p, go_next_primary_slot
			; 次の拡張スロット
	go_next_extend_slot:
			add		a, 0b00000100
			bit		4, a					; slot#?-4 になった？
			jp		z, slot_loop			; -- なっていない場合は、まだ同じ基本スロットの次の拡張スロットを探索
			; 次の基本スロット
	go_next_primary_slot:
			and		a, 0b00000011
			add		a, 0b00000001
			cp		a, 4					; slot#4-0 になった？
			ret		z						; -- slot#4-0 になった。つまり、カートリッジ見つからなかった。
			ld		b, a
			inc		hl
			; その基本スロットは拡張されているか？
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
;	ゲームカートリッジの hash値を求める
;	この ROM が page1 にあり、ゲームカートリッジも page1 にあるので、
;	ハッシュ計算ルーチンは page3 へコピーしてそこで実行する
; =============================================================================
			scope	get_hash
get_hash::
			; ROM上にある get_hash_sub を page3 の DRAM の所定の位置へコピー
			ld		hl, get_hash_sub_on_rom
			ld		de, get_hash_sub
			ld		bc, get_hash_sub_end - get_hash_sub
			ldir
			; コピーしたコードを呼び出す
			jp		get_hash_sub
			endscope

; =============================================================================
;	page1 をゲームカートリッジのスロットに切り替えて hash を計算してから
;	page1 をこのROMに戻す
; =============================================================================
get_hash_sub_on_rom::
			org		hash_sub
			scope	get_hash_sub
get_hash_sub::
			; page1 をゲームカートリッジに切り替える
			ld		a, [ cartridge ]
			ld		h, 0x40
			call	enaslt
			; hashを求める
			ld		hl, 0x4000
			ld		de, 0x1234
			ld		bc, 0x4000
		loop:
			; 偶数byte
			ld		a, [hl]
			inc		hl
			inc		a
			xor		a, e
			add		a, 3
			ld		e, a
			; 奇数byte
			ld		a, [hl]
			inc		hl
			adc		a, 7
			xor		a, d
			dec		a
			ld		d, a
			; ループ終わりか？
			dec		bc
			ld		a, c
			or		a, b
			jp		nz, loop
			; 求めた hash を保存
			ld		[ hash ], de
			; スロットを元に戻す
			ld		a, [ rom_slot ]
			ld		h, 0x40
			call	enaslt
			ret
get_hash_sub_end::
			endscope

			org		get_hash_sub_on_rom + (get_hash_sub_end - get_hash_sub)

; =============================================================================
;	[ESC]キーが押されているか確認する
; =============================================================================
			scope	check_esc_key
check_esc_key::
			di
			in		a, [ 0xAA ]			; PPI port B
			and		a, 0b11110000
			or		a, 7				; MSXキーマトリクス 行7 (bit2 が ESC に対応。押されてると 0)
			out		[ 0xAA ], a			; PPI port B : キーマトリクス 行7 を選択する
			nop
			in		a, [ 0xA9 ]			; MSXキーマトリクス
			ei
			and		a, 0b00000100		; ESCキーを抽出。押されてれば 0 になるので Zf = 1, 押されていなければ Zf = 0
			ret
			endscope

; =============================================================================
;	hash値に対応する palette_set_num を求める
; =============================================================================
			scope	hash_to_palette_num
hash_to_palette_num::
			ld		bc, [ hash ]
			ld		hl, hash_table
		loop:
			; hash_table配列の現在の参照要素の hash値を DE に、palette_set_numを A に格納
			ld		e, [hl]
			inc		hl
			ld		d, [hl]
			inc		hl
			ld		a, [hl]
			inc		hl
			; 番兵(palette_set_num = 0xFF)か？
			inc		a					; 番兵ならここで 0x00 になる
			jr		z, not_found
			dec		a					; inc a をキャンセルして戻す
			; DE と BC を比較する
			ex		de, hl
			or		a, a
			sbc		hl, bc
			ex		de, hl
			jr		nz, loop
			; hash_table に該当が見つからなかった場合は、強制的に palette_set_num = 0 にする
			; hash_table に該当が見つかった場合は、palette_set_num = hash_table から引いた値にする
		not_found:
			ld		[ palette_set_num ], a
			ret
			endscope

; =============================================================================
;	palette_set_num に対応する palette_set のアドレスを求める
; =============================================================================
			scope	update_palette_set_address
update_palette_set_address::
			; アドレス計算
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
			; 求めたアドレスを変数に保存
			ld		[ palette_set_address ], hl
			ret
			endscope

; =============================================================================
;	palette_set_address に保存されてるアドレスにあるパレット値に基づいて
;	カラーパレットを変更する
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
			; 16 palette (32byte) 設定する
			ld		hl, [ palette_set_address ]
			ld		bc, (32 << 8) | vdp_port2
			otir
			ret
			endscope

; =============================================================================
;	フォントデータ
; =============================================================================
font_data::
			include	"font.asm"

; =============================================================================
;	スプライトデータ
;	16ドット x 16ドット 2倍拡大スプライトを 4x4 で並べる
;	1個水平32ドット、4個で 128ドットなので、左にセンタリング 64ドット
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
;	文字列
; =============================================================================
s_title::
			ds		"<PALETTE CHANGER>"
			db		0

; =============================================================================
;	カラーパレットセット（32セット）
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
;	hash値とパレットセットの対応表
; =============================================================================
hash_entry	macro	vhash, vpalette_set_num
			dw		vhash
			db		vpalette_set_num
			endm

			include	"hash_to_palette.asm"

; =============================================================================
;	ワークエリア
; =============================================================================

rom_slot			:= 0xC000						; 1byte  : このROMが装着されているスロットのスロット番号
signature			:= rom_slot + 1					; 2bytes : ゲームカートリッジの探索時のワークエリア
cartridge			:= signature + 2				; 1byte  : ゲームカートリッジのスロット番号、見つからない場合は 0x00
palette_set_address	:= cartridge + 1				; 2bytes : 選択したパレットセットのアドレス
hash				:= palette_set_address + 2		; 2bytes : ゲームカートリッジのハッシュ値
palette_set_num		:= hash + 2						; 1byte  : 選択中のパレットセット番号
hash_sub			:= palette_set_num + 1			; hash_sub_size bytes: ハッシュ計算ルーチン置き場
