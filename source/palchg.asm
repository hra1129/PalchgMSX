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
			scope	get_this_slot
get_this_slot::
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
;	ゲームカートリッジのハッシュ値を求める
; =============================================================================
			scope	get_hash
get_hash::
			
			endscope

; =============================================================================
;	page1 をゲームカートリッジのスロットに切り替えて hash を計算してから
;	page1 をこのROMに戻す
; =============================================================================
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
			endscope

; =============================================================================
;	ワークエリア
; =============================================================================

rom_slot	:= 0xC000						; 1byte  : このROMが装着されているスロットのスロット番号
signature	:= rom_slot + 1					; 2bytes : ゲームカートリッジの探索時のワークエリア
cartridge	:= signature + 2				; 1byte  : ゲームカートリッジのスロット番号、見つからない場合は 0x00
hash		:= cartridge + 1				; 2bytes : ゲームカートリッジのハッシュ値
hash_sub	:= hash + 2						; hash_sub_size bytes: ハッシュ計算ルーチン置き場
