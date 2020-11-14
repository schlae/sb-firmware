; Firmware from Chinese SB clone, a "Protac AV202P3."
; Reversed and modified to work on genuine SB 1.X cards by
; @TubeTimeUS, 2018/10/05.
; Comments (C) TubeTime

;
;	Register/Memory Equates
;
.EQU autoinit_magic1, 10h
.EQU autoinit_magic2, 11h
.EQU dma_len_l_cp, 12h
.EQU dma_len_h_cp, 13h
.EQU ai_dma_len_l, 14h
.EQU ai_dma_len_h, 15h
.EQU test_reg, 18h
.EQU secret_accum, 19h
.EQU secret_rotater, 1ah
.EQU buf_counter, 1bh
.EQU timer_mode, 1ch
.EQU time_constant, 1dh
.EQU adpcm_mag, 1eh
.EQU misc_flags, 20h
.EQU status_bits, 21h
.EQU adpcm_buf, 23h
.EQU adpcm_sign, 24h
;
;	SFR Equates
;
.EQU port_dac_out, P1       ; was P2.
;
;	SFR bit Equates
;
.EQU pin_drequest, 0B5h     ; was 90h (p1.0)
.EQU pin_dma_enablel, 0B4h  ; was 91h (p1.1)
.EQU pin_dsp_busy, 0B3h     ; was 92h (p1.2)
.EQU pin_irequest, 0B2h     ; was 93h (p1.3)
.EQU pin_dav_dsp, 0A7h      ; was 94h (p1.4)
.EQU pin_dav_pc, 0A6h       ; was 95h (p1.5)
.EQU pin_adc_comp, 0A5h     ; was 96h (p1.6)
.EQU pin_mute_en, 0A0h      ; was 97h (p1.7)
.EQU pin_dac_0, 090h        ; was 0a0h (p2.0)
.EQU pin_dac_1, 091h        ; was 0a1h (p2.1)
.EQU pin_dac_2, 092h        ; was 0a2h (p2.2)
.EQU pin_dac_3, 093h        ; was 0a3h (p2.3)
.EQU pin_dac_4, 094h        ; was 0a4h (p2.4)
.EQU pin_dac_5, 095h        ; was 0a5h (p2.5)
.EQU pin_dac_6, 096h        ; was 0a6h (p2.6)
.EQU pin_dac_7, 097h        ; was 0a7h (p2.7)
;
;	Memory bit Equates
;
;.EQU misc_flags.0, 0
;.EQU misc_flags.1, 1
;.EQU misc_flags.2, 2
.EQU use_timer_table, 3
.EQU speaker_status, 8
.EQU flag_dac_silenc, 0bh
.EQU flag_dma_dac_2, 0ch
.EQU flag_dma_dac_26, 0dh
.EQU flag_dma_dac_4, 0eh
.EQU flag_dma_dac_8, 0fh
;.EQU adpcm_buf.0, 18h
;.EQU adpcm_buf.1, 19h
;.EQU adpcm_buf.2, 1ah
;.EQU adpcm_buf.3, 1bh
;.EQU adpcm_sign.7, 27h



	.org	0
;
RESET:	ajmp	start

.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
;
	.org	0bh
;
TF0_VECTOR:
	ljmp	timer_isr

.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
;
	.org	30h
;
start:
	mov	sp,#30h
	setb	pin_dsp_busy
	setb	pin_dma_enablel
	setb	wr
	setb	rd
	clr	pin_drequest
	setb	pt0
	mov	th1,#0feh
	mov	tl1,#0feh
	mov	tmod,#22h
	mov	scon,#42h
	mov	pcon,#80h
	setb	ren
	setb	tr1
	mov	a,#0aah
	cjne	a,autoinit_magic2,cold_boot
	mov	a,#55h
	cjne	a,autoinit_magic1,cold_boot
	mov	autoinit_magic1,#0
	mov	autoinit_magic2,#0
	jnb	speaker_status,warm_boot
	mov	port_dac_out,#80h
	clr	pin_mute_en
	sjmp	warm_boot
;
cold_boot:
	mov	r0,#40h
	mov	r1,#40h
	mov	r4,#0
	mov	r6,#2
	mov	time_constant,#9ch
	mov	secret_accum,#0aah
	mov	secret_rotater,#96h
	mov	status_bits,#0
	mov	ai_dma_len_l,#0ffh
	mov	ai_dma_len_h,#7
	mov	port_dac_out,#80h
warm_boot:
	mov	r3,#0
	mov	misc_flags,#0
	mov	a,time_constant
	mov	th0,a
	mov	tl0,a
	setb	ea
	clr	pin_dsp_busy
	mov	a,#0aah
X009a:	jb	pin_dav_pc,X009a
	movx	@r0,a
wait_for_command:
	jnb	pin_dav_dsp,wait_for_command
	clr	tr0
	setb	pin_dsp_busy
	movx	a,@r0
	jbc	acc.7,do_cmd_hi
	mov	dptr,#cmd_lo_table
	rl	a
	jmp	@a+dptr
;
do_cmd_hi:
	mov	dptr,#cmd_hi_table
	rl	a
	jmp	@a+dptr
;
cmd_0_3_nop:
	clr	pin_dsp_busy
	ajmp	wait_for_command
;
cmd_4_7_status:
	clr	pin_dsp_busy
	mov	a,status_bits
X00bb:	jb	pin_dav_pc,X00bb
	movx	@r0,a
	jb	pin_dma_enablel,cmd_0_3_nop
	setb	tr0
	ajmp	wait_for_command
;
cmd_8_f:
	clr	pin_dsp_busy
X00c8:	sjmp	X00c8
;
cmd_10_13_direct_dac_8:
	clr	pin_dsp_busy
X00cc:	jnb	pin_dav_dsp,X00cc
	movx	a,@r0
	mov	port_dac_out,a
	ajmp	wait_for_command
;
cmd_14_15_dma_dac_8:
	jb	pin_dma_enablel,X00d9
	ajmp	update_dma_len
;
X00d9:	clr	pin_dsp_busy
X00db:	jnb	pin_dav_dsp,X00db
	movx	a,@r0
	mov	r5,a
X00e0:	jnb	pin_dav_dsp,X00e0
	movx	a,@r0
	mov	r6,a
	setb	pin_dsp_busy
	clr	pin_dma_enablel
	mov	timer_mode,#0
	setb	flag_dma_dac_8
	ajmp	start_timer
;
cmd_16_dma_dac_2:
	jb	pin_dma_enablel,X00f5
	ajmp	update_dma_len
;
X00f5:	clr	pin_dsp_busy
X00f7:	jnb	pin_dav_dsp,X00f7
	movx	a,@r0
	mov	r5,a
X00fc:	jnb	pin_dav_dsp,X00fc
	movx	a,@r0
	mov	r6,a
	setb	pin_dsp_busy
	clr	pin_dma_enablel
	mov	timer_mode,#2
	setb	flag_dma_dac_2
	setb	pin_drequest
	clr	pin_drequest
X010e:	jnb	pin_dav_dsp,X010e
	movx	a,@r0
	mov	adpcm_buf,a
	mov	r3,#4
	ajmp	start_timer
;
cmd_17_dma_dac_2_ref:
	jb	pin_dma_enablel,X011d
	ajmp	update_dma_len
;
X011d:	clr	pin_dsp_busy
X011f:	jnb	pin_dav_dsp,X011f
	movx	a,@r0
	mov	r5,a
X0124:	jnb	pin_dav_dsp,X0124
	movx	a,@r0
	mov	r6,a
	setb	pin_dsp_busy
	clr	pin_dma_enablel
	mov	timer_mode,#2
	setb	flag_dma_dac_2
	setb	pin_drequest
	clr	pin_drequest
X0136:	jnb	pin_dav_dsp,X0136
	movx	a,@r0
	mov	r2,a
	mov	port_dac_out,a
	mov	r7,#0
	mov	r3,#1
	ajmp	start_timer
;
cmd_18_19_1c_1d_dma_dac_8_ai:
	setb	misc_flags.0
	mov	r5,ai_dma_len_l
	mov	r6,ai_dma_len_h
	clr	pin_dma_enablel
	mov	timer_mode,#0
	setb	flag_dma_dac_8
	ajmp	start_timer
;
cmd_1a_1e:
	setb	misc_flags.0
	mov	r5,ai_dma_len_l
	mov	r6,ai_dma_len_h
	clr	pin_dma_enablel
	mov	timer_mode,#2
	setb	flag_dma_dac_2
	setb	pin_drequest
	clr	pin_drequest
X0163:	jnb	pin_dav_dsp,X0163
	movx	a,@r0
	mov	adpcm_buf,a
	mov	r3,#4
	ajmp	start_timer
;
cmd_1b_1f_dma_dac_2_ref_ai:
	setb	misc_flags.0
	mov	r5,ai_dma_len_l
	mov	r6,ai_dma_len_h
	clr	pin_dma_enablel
	mov	timer_mode,#2
	setb	flag_dma_dac_2
	setb	pin_drequest
	clr	pin_drequest
X017e:	jnb	pin_dav_dsp,X017e
	movx	a,@r0
	mov	r2,a
	mov	port_dac_out,a
	mov	r7,#0
	mov	r3,#1
	ajmp	start_timer
;
cmd_20_23_direct_adc_8:
	clr	pin_dsp_busy
	lcall	get_adc_sample
	ajmp	wait_for_command
;
cmd_24_27_dma_adc_8:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X01aa
X0197:	jnb	pin_dav_dsp,X0197
	movx	a,@r0
	mov	r5,a
X019c:	jnb	pin_dav_dsp,X019c
	movx	a,@r0
	mov	r6,a
	clr	pin_dma_enablel
	setb	21h.2
	mov	timer_mode,#0ah
	ajmp	start_timer
;
X01aa:	jnb	pin_dav_dsp,X01aa
	movx	a,@r0
	mov	dma_len_l_cp,a
X01b0:	jnb	pin_dav_dsp,X01b0
	movx	a,@r0
	mov	dma_len_h_cp,a
	setb	misc_flags.1
	clr	pin_dma_enablel
	setb	21h.2
	mov	timer_mode,#0ah
	ajmp	start_timer
;
cmd_28_2f_direct_adc_8_burst:
	clr	pin_dsp_busy
	setb	misc_flags.0
	mov	r5,ai_dma_len_l
	mov	r6,ai_dma_len_h
	clr	pin_dma_enablel
	setb	21h.2
	mov	timer_mode,#0ah
	ajmp	start_timer
;
cmd_38_3f_midi_write_poll:
	clr	pin_dsp_busy
X01d4:	jnb	ti,X01d4
	clr	ti
X01d9:	jnb	pin_dav_dsp,X01d9
	movx	a,@r0
	setb	tr0
	mov	sbuf,a
	ljmp	wait_for_command
;
cmd_30_midi_read_poll:
	clr	pin_dsp_busy
	jb	pin_dma_enablel,do_midi_read_poll
	setb	tr0
	ajmp	wait_for_command
;
do_midi_read_poll:
	mov	a,sbuf
	clr	ri
	mov	a,#40h
	mov	r0,a
	mov	r1,a
	mov	r4,#0
	ajmp	check_for_ri
;
check_for_pc:
	jnb	pin_dav_dsp,check_for_ri
	movx	a,@r0
midi_cmd_term:
	mov	a,#40h
	mov	r0,a
	mov	r1,a
	mov	r4,#0
	clr	et0
	clr	tr0
	mov	autoinit_magic1,#0
	mov	autoinit_magic2,#0
	clr	use_timer_table
	mov	tmod,#22h
	ljmp	wait_for_command
;
check_for_ri:
	jb	ri,has_data
	cjne	r4,#0,send_data
	sjmp	check_for_pc
;
send_data:
	jb	pin_dav_pc,check_for_pc
	mov	a,@r1
	inc	r1
	dec	r4
	cjne	r1,#80h,X0228
	mov	r1,#40h
X0228:	movx	@r0,a
	sjmp	check_for_pc
;
has_data:
	mov	a,sbuf
	cjne	r4,#40h,store_data
	sjmp	X023a
;
store_data:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X023a
	mov	r0,#40h
X023a:	clr	ri
	sjmp	check_for_pc
;
cmd_31_midi_read_int:
	clr	pin_dsp_busy
	jb	pin_dma_enablel,do_midi_read_int
	setb	tr0
	ajmp	wait_for_command
;
do_midi_read_int:
	mov	a,sbuf
	clr	ri
	mov	a,#40h
	mov	r0,a
	mov	r1,a
	mov	r4,#0
	ajmp	check_for_ri2
;
check_for_pc2:
	jnb	pin_dav_dsp,check_for_ri2
	movx	a,@r0
	ajmp	midi_cmd_term
;
check_for_ri2:
	jb	ri,has_data2
	cjne	r4,#0,send_data2
	sjmp	check_for_pc2
;
send_data2:
	jb	pin_dav_pc,check_for_pc2
	mov	a,@r1
	inc	r1
	dec	r4
	cjne	r1,#80h,X026c
	mov	r1,#40h
X026c:	movx	@r0,a
	clr	pin_irequest
	setb	pin_irequest
	sjmp	check_for_pc2
;
has_data2:
	mov	a,sbuf
	cjne	r4,#40h,store_data2
	sjmp	X0282
;
store_data2:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X0282
	mov	r0,#40h
X0282:	clr	ri
	sjmp	check_for_pc2
;
cmd_32_midi_read_timestamp_poll:
	clr	pin_dsp_busy
	jb	pin_dma_enablel,do_midi_read_timestamp_poll
	setb	tr0
	ajmp	wait_for_command
;
do_midi_read_timestamp_poll:
	mov	tmod,#21h
	setb	use_timer_table
	mov	tl0,#17h
	mov	th0,#0fch
	clr	a
	mov	r7,a
	mov	r5,a
	mov	r6,a
	setb	et0
	setb	tr0
	mov	a,sbuf
	clr	ri
	mov	a,#40h
	mov	r0,a
	mov	r1,a
	mov	r4,#0
	ajmp	check_for_ri3
;
check_for_pc3:
	jnb	pin_dav_dsp,check_for_ri3
	movx	a,@r0
	ajmp	midi_cmd_term
;
check_for_ri3:
	jb	ri,has_data3
	cjne	r4,#0,send_data3
	sjmp	check_for_pc3
;
send_data3:
	jb	pin_dav_pc,check_for_pc3
	mov	a,@r1
	inc	r1
	dec	r4
	cjne	r1,#80h,X02c7
	mov	r1,#40h
X02c7:	movx	@r0,a
	sjmp	check_for_pc3
;
has_data3:
	clr	tr0
	mov	a,r7
	cjne	r4,#40h,store_ts3_r7
	sjmp	X02da
;
store_ts3_r7:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X02da
	mov	r0,#40h
X02da:	mov	a,r5
	cjne	r4,#40h,store_ts3_r5
	sjmp	X02e8
;
store_ts3_r5:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X02e8
	mov	r0,#40h
X02e8:	mov	a,r6
	cjne	r4,#40h,store_ts3_r6
	sjmp	X02f6
;
store_ts3_r6:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X02f6
	mov	r0,#40h
X02f6:	setb	tr0
	mov	a,sbuf
	cjne	r4,#40h,store_data3
	sjmp	X0307
;
store_data3:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X0307
	mov	r0,#40h
X0307:	clr	ri
	sjmp	check_for_pc3
;
cmd_33_midi_read_timestamp_int:
	clr	pin_dsp_busy
	jb	pin_dma_enablel,do_midi_read_timestamp_int
	setb	tr0
	ajmp	wait_for_command
;
do_midi_read_timestamp_int:
	mov	tmod,#21h
	setb	use_timer_table
	mov	tl0,#17h
	mov	th0,#0fch
	clr	a
	mov	r7,a
	mov	r5,a
	mov	r6,a
	setb	et0
	setb	tr0
	mov	a,sbuf
	clr	ri
	mov	a,#40h
	mov	r0,a
	mov	r1,a
	mov	r4,#0
	ajmp	check_for_ri4
;
check_for_pc4:
	jnb	pin_dav_dsp,check_for_ri4
	movx	a,@r0
	ajmp	midi_cmd_term
;
check_for_ri4:
	jb	ri,has_data4
	cjne	r4,#0,send_data4
	sjmp	check_for_pc4
;
send_data4:
	jb	pin_dav_pc,check_for_pc4
	mov	a,@r1
	inc	r1
	dec	r4
	cjne	r1,#80h,X034c
	mov	r1,#40h
X034c:	movx	@r0,a
	clr	pin_irequest
	setb	pin_irequest
	sjmp	check_for_pc4
;
has_data4:
	clr	tr0
	mov	a,r7
	cjne	r4,#40h,store_ts4_r7
	sjmp	X0363
;
store_ts4_r7:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X0363
	mov	r0,#40h
X0363:	mov	a,r5
	cjne	r4,#40h,store_ts4_r5
	sjmp	X0371
;
store_ts4_r5:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X0371
	mov	r0,#40h
X0371:	mov	a,r6
	cjne	r4,#40h,store_ts4_r6
	sjmp	X037f
;
store_ts4_r6:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X037f
	mov	r0,#40h
X037f:	setb	tr0
	mov	a,sbuf
	cjne	r4,#40h,store_data4
	sjmp	X0390
;
store_data4:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X0390
	mov	r0,#40h
X0390:	clr	ri
	sjmp	check_for_pc4
;
cmd_34_midi_read_poll_write:
	clr	pin_dsp_busy
	jb	pin_dma_enablel,do_midi_read_poll_write
	setb	tr0
	ajmp	wait_for_command
;
do_midi_read_poll_write:
	mov	autoinit_magic1,#55h
	mov	autoinit_magic2,#0aah
	mov	a,sbuf
	clr	ri
	mov	a,#40h
	mov	r0,a
	mov	r1,a
	mov	r4,#0
	ajmp	check_for_ri5
;
check_for_pc5:
	jnb	pin_dav_dsp,check_for_ri5
	movx	a,@r0
X03b3:	jnb	ti,X03b3
	clr	ti
	mov	sbuf,a
check_for_ri5:
	jb	ri,has_data5
	cjne	r4,#0,send_data5
	sjmp	check_for_pc5
;
send_data5:
	jb	pin_dav_pc,check_for_pc5
	mov	a,@r1
	inc	r1
	dec	r4
	cjne	r1,#80h,X03cd
	mov	r1,#40h
X03cd:	movx	@r0,a
	sjmp	check_for_pc5
;
has_data5:
	mov	a,sbuf
	cjne	r4,#40h,store_data5
	sjmp	X03df
;
store_data5:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X03df
	mov	r0,#40h
X03df:	clr	ri
	sjmp	check_for_pc5
;
cmd_35_midi_read_int_write_poll:
	clr	pin_dsp_busy
	jb	pin_dma_enablel,do_midi_read_int_write_poll
	setb	tr0
	ajmp	wait_for_command
;
do_midi_read_int_write_poll:
	mov	autoinit_magic1,#55h
	mov	autoinit_magic2,#0aah
	mov	a,sbuf
	clr	ri
	mov	a,#40h
	mov	r0,a
	mov	r1,a
	mov	r4,#0
	ajmp	check_for_ri6
;
check_for_pc6:
	jnb	pin_dav_dsp,check_for_ri6
	movx	a,@r0
X0402:	jnb	ti,X0402
	clr	ti
	mov	sbuf,a
check_for_ri6:
	jb	ri,has_data6
	cjne	r4,#0,send_data6
	sjmp	check_for_pc6
;
send_data6:
	jb	pin_dav_pc,check_for_pc6
	mov	a,@r1
	inc	r1
	dec	r4
	cjne	r1,#80h,X041c
	mov	r1,#40h
X041c:	movx	@r0,a
	clr	pin_irequest
	setb	pin_irequest
	sjmp	check_for_pc6
;
has_data6:
	mov	a,sbuf
	cjne	r4,#40h,store_data6
	sjmp	X0432
;
store_data6:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X0432
	mov	r0,#40h
X0432:	clr	ri
	sjmp	check_for_pc6
;
cmd_36:	clr	pin_dsp_busy
	jb	pin_dma_enablel,X043f
	setb	tr0
	ajmp	wait_for_command
;
X043f:	mov	autoinit_magic1,#55h
	mov	autoinit_magic2,#0aah
	mov	tmod,#21h
	setb	use_timer_table
	mov	tl0,#17h
	mov	th0,#0fch
	clr	a
	mov	r7,a
	mov	r5,a
	mov	r6,a
	setb	et0
	setb	tr0
	mov	a,sbuf
	clr	ri
	mov	a,#40h
	mov	r0,a
	mov	r1,a
	mov	r4,#0
	ajmp	check_for_ri7
;
check_for_pc7:
	jnb	pin_dav_dsp,check_for_ri7
	movx	a,@r0
X0468:	jnb	ti,X0468
	clr	ti
	mov	sbuf,a
check_for_ri7:
	jb	ri,has_data7
	cjne	r4,#0,send_data7
	sjmp	check_for_pc7
;
send_data7:
	jb	pin_dav_pc,check_for_pc7
	mov	a,@r1
	inc	r1
	dec	r4
	cjne	r1,#80h,X0482
	mov	r1,#40h
X0482:	movx	@r0,a
	sjmp	check_for_pc7
;
has_data7:
	clr	tr0
	mov	a,r7
	cjne	r4,#40h,store_ts7_r7
	sjmp	X0495
;
store_ts7_r7:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X0495
	mov	r0,#40h
X0495:	mov	a,r5
	cjne	r4,#40h,store_ts7_r5
	sjmp	X04a3
;
store_ts7_r5:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X04a3
	mov	r0,#40h
X04a3:	mov	a,r6
	cjne	r4,#40h,store_ts7_r6
	sjmp	X04b1
;
store_ts7_r6:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X04b1
	mov	r0,#40h
X04b1:	setb	tr0
	mov	a,sbuf
	cjne	r4,#40h,store_data7
	sjmp	X04c2
;
store_data7:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X04c2
	mov	r0,#40h
X04c2:	clr	ri
	sjmp	check_for_pc7
;
cmd_37_midi_read_timestamp_int_write_poll:
	clr	pin_dsp_busy
	jb	pin_dma_enablel,do_midi_read_timestamp_int_write_poll
	setb	tr0
	ajmp	wait_for_command
;
do_midi_read_timestamp_int_write_poll:
	mov	autoinit_magic1,#55h
	mov	autoinit_magic2,#0aah
	mov	tmod,#21h
	setb	use_timer_table
	mov	tl0,#17h
	mov	th0,#0fch
	clr	a
	mov	r7,a
	mov	r5,a
	mov	r6,a
	setb	et0
	setb	tr0
	mov	a,sbuf
	clr	ri
	mov	a,#40h
	mov	r0,a
	mov	r1,a
	mov	r4,#0
	ajmp	check_for_ri8
;
check_for_pc8:
	jnb	pin_dav_dsp,check_for_ri8
	movx	a,@r0
X04f8:	jnb	ti,X04f8
	clr	ti
	mov	sbuf,a
check_for_ri8:
	jb	ri,has_data8
	cjne	r4,#0,send_data8
	sjmp	check_for_pc8
;
send_data8:
	jb	pin_dav_pc,check_for_pc8
	mov	a,@r1
	inc	r1
	dec	r4
	cjne	r1,#80h,X0512
	mov	r1,#40h
X0512:	movx	@r0,a
	clr	pin_irequest
	setb	pin_irequest
	sjmp	check_for_pc8
;
has_data8:
	clr	tr0
	mov	a,r7
	cjne	r4,#40h,store_ts8_r7
	sjmp	X0529
;
store_ts8_r7:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X0529
	mov	r0,#40h
X0529:	mov	a,r5
	cjne	r4,#40h,store_ts8_r5
	sjmp	X0537
;
store_ts8_r5:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X0537
	mov	r0,#40h
X0537:	mov	a,r6
	cjne	r4,#40h,store_ts8_r6
	sjmp	X0545
;
store_ts8_r6:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X0545
	mov	r0,#40h
X0545:	setb	tr0
	mov	a,sbuf
	cjne	r4,#40h,store_data8
	sjmp	X0556
;
store_data8:
	mov	@r0,a
	inc	r0
	inc	r4
	cjne	r0,#80h,X0556
	mov	r0,#40h
X0556:	clr	ri
	sjmp	check_for_pc8
;
cmd_40_47_set_time_constant:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X057e
X055f:	jnb	pin_dav_dsp,X055f
	movx	a,@r0
	mov	time_constant,a
	mov	tl0,a
	mov	th0,a
	ajmp	wait_for_command
;
cmd_48_4f_set_dma_block_size:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X057e
X0570:	jnb	pin_dav_dsp,X0570
	movx	a,@r0
	mov	ai_dma_len_l,a
X0576:	jnb	pin_dav_dsp,X0576
	movx	a,@r0
	mov	ai_dma_len_h,a
	ajmp	wait_for_command
;
X057e:	setb	tr0
	ajmp	wait_for_command
;
cmd_50_52_54_56:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X057e
	clr	et0
	clr	tr0
	ajmp	wait_for_command
;
cmd_51_53_55_57:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X057e
	setb	pin_dsp_busy
	ajmp	wait_for_command
;
cmd_58_5a_5c_5e:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X057e
X059b:	jnb	pin_dav_dsp,X059b
	movx	a,@r0
	mov	buf_counter,a
X05a1:	jnb	pin_dav_dsp,X05a1
	movx	a,@r0
X05a5:	jnb	pin_dav_dsp,X05a5
	movx	a,@r0
X05a9:	jnb	pin_dav_dsp,X05a9
	movx	a,@r0
	mov	r0,#40h
X05af:	jnb	pin_dav_dsp,X05af
	movx	a,@r0
	mov	@r0,a
	inc	r0
	dec	buf_counter
	djnz	buf_counter,X05af
	mov	r1,#40h
	ajmp	wait_for_command
;
cmd_59_5b_5d_5f:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X057e
X05c3:	jnb	pin_dav_dsp,X05c3
	movx	a,@r0
	mov	buf_counter,a
X05c9:	jnb	pin_dav_dsp,X05c9
	movx	a,@r0
X05cd:	jnb	pin_dav_dsp,X05cd
	movx	a,@r0
X05d1:	jnb	pin_dav_dsp,X05d1
	movx	a,@r0
	mov	r0,#40h
X05d7:	jnb	pin_dav_dsp,X05d7
	movx	a,@r0
	mov	@r0,a
	inc	r0
	dec	buf_counter
	djnz	buf_counter,X05d7
	mov	r1,#40h
	setb	pin_dsp_busy
	ajmp	wait_for_command
;
cmd_60_63_disable_stereo_in:
	clr	pin_dsp_busy
X05ea:	ajmp	wait_for_command
;
cmd_64_67:
	clr	pin_dsp_busy
	jb	pin_dma_enablel,X05ea
	mov	a,status_bits
X05f3:	jb	pin_dav_pc,X05f3
	movx	@r0,a
	jb	pin_dma_enablel,X05ea
	setb	tr0
	ajmp	wait_for_command
;
cmd_68_6f_enable_stereo_in:
	clr	pin_dsp_busy
	jb	pin_dma_enablel,X05ea
X0603:	sjmp	X0603
;
cmd_70_78_7c:
	setb	misc_flags.0
	mov	r5,ai_dma_len_l
	mov	r6,ai_dma_len_h
	sjmp	X0620
;
cmd_74_dma_dac_4:
	jb	pin_dma_enablel,X0612
	ajmp	update_dma_len
;
X0612:	clr	pin_dsp_busy
X0614:	jnb	pin_dav_dsp,X0614
	movx	a,@r0
	mov	r5,a
X0619:	jnb	pin_dav_dsp,X0619
	movx	a,@r0
	mov	r6,a
	setb	pin_dsp_busy
X0620:	clr	pin_dma_enablel
	mov	timer_mode,#4
	setb	flag_dma_dac_4
	setb	pin_drequest
	clr	pin_drequest
X062b:	jnb	pin_dav_dsp,X062b
	movx	a,@r0
	mov	adpcm_buf,a
	mov	r3,#2
	ajmp	start_timer
;
cmd_71_79_7d:
	setb	misc_flags.0
	mov	r5,ai_dma_len_l
	mov	r6,ai_dma_len_h
	sjmp	X0650
;
cmd_75_dma_dac_4_ref:
	jb	pin_dma_enablel,X0642
	ajmp	update_dma_len
;
X0642:	clr	pin_dsp_busy
X0644:	jnb	pin_dav_dsp,X0644
	movx	a,@r0
	mov	r5,a
X0649:	jnb	pin_dav_dsp,X0649
	movx	a,@r0
	mov	r6,a
	setb	pin_dsp_busy
X0650:	clr	pin_dma_enablel
	mov	timer_mode,#4
	setb	flag_dma_dac_4
	setb	pin_drequest
	clr	pin_drequest
X065b:	jnb	pin_dav_dsp,X065b
	movx	a,@r0
	mov	r2,a
	mov	port_dac_out,a
	mov	r7,#0
	mov	r3,#1
	ajmp	start_timer
;
cmd_72_7a_7e:
	setb	misc_flags.0
	mov	r5,ai_dma_len_l
	mov	r6,ai_dma_len_h
	sjmp	X0683
;
cmd_76_dma_dac_2_6:
	jb	pin_dma_enablel,X0675
	ajmp	update_dma_len
;
X0675:	clr	pin_dsp_busy
X0677:	jnb	pin_dav_dsp,X0677
	movx	a,@r0
	mov	r5,a
X067c:	jnb	pin_dav_dsp,X067c
	movx	a,@r0
	mov	r6,a
	setb	pin_dsp_busy
X0683:	clr	pin_dma_enablel
	mov	timer_mode,#6
	setb	flag_dma_dac_26
	setb	pin_drequest
	clr	pin_drequest
X068e:	jnb	pin_dav_dsp,X068e
	movx	a,@r0
	mov	adpcm_buf,a
	mov	r3,#3
	ajmp	start_timer
;
cmd_73_7b_7f:
	setb	misc_flags.0
	mov	r5,ai_dma_len_l
	mov	r6,ai_dma_len_h
	sjmp	X06b3
;
cmd_77_dma_dac_2_6_ref:
	jb	pin_dma_enablel,X06a5
	ajmp	update_dma_len
;
X06a5:	clr	pin_dsp_busy
X06a7:	jnb	pin_dav_dsp,X06a7
	movx	a,@r0
	mov	r5,a
X06ac:	jnb	pin_dav_dsp,X06ac
	movx	a,@r0
	mov	r6,a
	setb	pin_dsp_busy
X06b3:	clr	pin_dma_enablel
	mov	timer_mode,#6
	setb	flag_dma_dac_26
	setb	pin_drequest
	clr	pin_drequest
X06be:	jnb	pin_dav_dsp,X06be
	movx	a,@r0
	mov	r2,a
	mov	port_dac_out,a
	mov	r7,#0
	mov	r3,#1
	ajmp	start_timer
;
cmd_lo_table:
	ajmp	cmd_0_3_nop
;
	ajmp	cmd_0_3_nop
;
	ajmp	cmd_0_3_nop
;
	ajmp	cmd_0_3_nop
;
	ajmp	cmd_4_7_status
;
	ajmp	cmd_4_7_status
;
	ajmp	cmd_4_7_status
;
	ajmp	cmd_4_7_status
;
	ajmp	cmd_8_f
;
	ajmp	cmd_8_f
;
	ajmp	cmd_8_f
;
	ajmp	cmd_8_f
;
	ajmp	cmd_8_f
;
	ajmp	cmd_8_f
;
	ajmp	cmd_8_f
;
	ajmp	cmd_8_f
;
	ajmp	cmd_10_13_direct_dac_8
;
	ajmp	cmd_10_13_direct_dac_8
;
	ajmp	cmd_10_13_direct_dac_8
;
	ajmp	cmd_10_13_direct_dac_8
;
	ajmp	cmd_14_15_dma_dac_8
;
	ajmp	cmd_14_15_dma_dac_8
;
	ajmp	cmd_16_dma_dac_2
;
	ajmp	cmd_17_dma_dac_2_ref
;
	ajmp	cmd_18_19_1c_1d_dma_dac_8_ai
;
	ajmp	cmd_18_19_1c_1d_dma_dac_8_ai
;
	ajmp	cmd_1a_1e
;
	ajmp	cmd_1b_1f_dma_dac_2_ref_ai
;
	ajmp	cmd_18_19_1c_1d_dma_dac_8_ai
;
	ajmp	cmd_18_19_1c_1d_dma_dac_8_ai
;
	ajmp	cmd_1a_1e
;
	ajmp	cmd_1b_1f_dma_dac_2_ref_ai
;
	ajmp	cmd_20_23_direct_adc_8
;
	ajmp	cmd_20_23_direct_adc_8
;
	ajmp	cmd_20_23_direct_adc_8
;
	ajmp	cmd_20_23_direct_adc_8
;
	ajmp	cmd_24_27_dma_adc_8
;
	ajmp	cmd_24_27_dma_adc_8
;
	ajmp	cmd_24_27_dma_adc_8
;
	ajmp	cmd_24_27_dma_adc_8
;
	ajmp	cmd_28_2f_direct_adc_8_burst
;
	ajmp	cmd_28_2f_direct_adc_8_burst
;
	ajmp	cmd_28_2f_direct_adc_8_burst
;
	ajmp	cmd_28_2f_direct_adc_8_burst
;
	ajmp	cmd_28_2f_direct_adc_8_burst
;
	ajmp	cmd_28_2f_direct_adc_8_burst
;
	ajmp	cmd_28_2f_direct_adc_8_burst
;
	ajmp	cmd_28_2f_direct_adc_8_burst
;
	ajmp	cmd_30_midi_read_poll
;
	ajmp	cmd_31_midi_read_int
;
	ajmp	cmd_32_midi_read_timestamp_poll
;
	ajmp	cmd_33_midi_read_timestamp_int
;
	ajmp	cmd_34_midi_read_poll_write
;
	ajmp	cmd_35_midi_read_int_write_poll
;
	ajmp	cmd_36
;
	ajmp	cmd_37_midi_read_timestamp_int_write_poll
;
	ajmp	cmd_38_3f_midi_write_poll
;
	ajmp	cmd_38_3f_midi_write_poll
;
	ajmp	cmd_38_3f_midi_write_poll
;
	ajmp	cmd_38_3f_midi_write_poll
;
	ajmp	cmd_38_3f_midi_write_poll
;
	ajmp	cmd_38_3f_midi_write_poll
;
	ajmp	cmd_38_3f_midi_write_poll
;
	ajmp	cmd_38_3f_midi_write_poll
;
	ajmp	cmd_40_47_set_time_constant
;
	ajmp	cmd_40_47_set_time_constant
;
	ajmp	cmd_40_47_set_time_constant
;
	ajmp	cmd_40_47_set_time_constant
;
	ajmp	cmd_40_47_set_time_constant
;
	ajmp	cmd_40_47_set_time_constant
;
	ajmp	cmd_40_47_set_time_constant
;
	ajmp	cmd_40_47_set_time_constant
;
	ajmp	cmd_48_4f_set_dma_block_size
;
	ajmp	cmd_48_4f_set_dma_block_size
;
	ajmp	cmd_48_4f_set_dma_block_size
;
	ajmp	cmd_48_4f_set_dma_block_size
;
	ajmp	cmd_48_4f_set_dma_block_size
;
	ajmp	cmd_48_4f_set_dma_block_size
;
	ajmp	cmd_48_4f_set_dma_block_size
;
	ajmp	cmd_48_4f_set_dma_block_size
;
	ajmp	cmd_50_52_54_56
;
	ajmp	cmd_51_53_55_57
;
	ajmp	cmd_50_52_54_56
;
	ajmp	cmd_51_53_55_57
;
	ajmp	cmd_50_52_54_56
;
	ajmp	cmd_51_53_55_57
;
	ajmp	cmd_50_52_54_56
;
	ajmp	cmd_51_53_55_57
;
	ajmp	cmd_58_5a_5c_5e
;
	ajmp	cmd_59_5b_5d_5f
;
	ajmp	cmd_58_5a_5c_5e
;
	ajmp	cmd_59_5b_5d_5f
;
	ajmp	cmd_58_5a_5c_5e
;
	ajmp	cmd_59_5b_5d_5f
;
	ajmp	cmd_58_5a_5c_5e
;
	ajmp	cmd_59_5b_5d_5f
;
	ajmp	cmd_60_63_disable_stereo_in
;
	ajmp	cmd_60_63_disable_stereo_in
;
	ajmp	cmd_60_63_disable_stereo_in
;
	ajmp	cmd_60_63_disable_stereo_in
;
	ajmp	cmd_64_67
;
	ajmp	cmd_64_67
;
	ajmp	cmd_64_67
;
	ajmp	cmd_64_67
;
	ajmp	cmd_68_6f_enable_stereo_in
;
	ajmp	cmd_68_6f_enable_stereo_in
;
	ajmp	cmd_68_6f_enable_stereo_in
;
	ajmp	cmd_68_6f_enable_stereo_in
;
	ajmp	cmd_68_6f_enable_stereo_in
;
	ajmp	cmd_68_6f_enable_stereo_in
;
	ajmp	cmd_68_6f_enable_stereo_in
;
	ajmp	cmd_68_6f_enable_stereo_in
;
	ajmp	cmd_70_78_7c
;
	ajmp	cmd_71_79_7d
;
	ajmp	cmd_72_7a_7e
;
	ajmp	cmd_73_7b_7f
;
	ajmp	cmd_74_dma_dac_4
;
	ajmp	cmd_75_dma_dac_4_ref
;
	ajmp	cmd_76_dma_dac_2_6
;
	ajmp	cmd_77_dma_dac_2_6_ref
;
	ajmp	cmd_70_78_7c
;
	ajmp	cmd_71_79_7d
;
	ajmp	cmd_72_7a_7e
;
	ajmp	cmd_73_7b_7f
;
	ajmp	cmd_70_78_7c
;
	ajmp	cmd_71_79_7d
;
	ajmp	cmd_72_7a_7e
;
	ajmp	cmd_73_7b_7f
;
update_dma_len:
	clr	pin_dsp_busy
X07cd:	jnb	pin_dav_dsp,X07cd
	movx	a,@r0
	mov	dma_len_l_cp,a
X07d3:	jnb	pin_dav_dsp,X07d3
	movx	a,@r0
	mov	dma_len_h_cp,a
	setb	misc_flags.1
	setb	et0
	setb	tr0
	ajmp	wait_for_command
;
start_timer:
	clr	pin_dsp_busy
	setb	et0
	setb	tr0
	ajmp	wait_for_command

.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
;
	.org	801h
;
	.db	'('+80h,'C'+80h,')'+80h,'1'+80h,'9'+80h,'9'+80h
	.db	'2'+80h,' '+80h,'A'+80h,'n'+80h,'c'+80h,'h'+80h
	.db	'o'+80h,'r'+80h,' '+80h,'E'+80h,'l'+80h,'e'+80h
	.db	'c'+80h,'t'+80h,'r'+80h,'o'+80h,'n'+80h,'i'+80h
	.db	'c'+80h,'s'+80h,' '+80h,'C'+80h,'o'+80h,'.'+80h
	.db	','+80h,0
adpcm_table:
	.db	0,1,2,3,4,5,6,7
	.db	8,9,0ah,0bh,0ch,0dh,0eh,0fh
	.db	1,3,5,7,9,0bh,0dh,0fh
	.db	11h,13h,15h,17h,19h,1bh,1dh,1fh
	.db	2,6,0ah,0eh,12h,16h,1ah,1eh
	.db	22h,26h,2ah,2eh,32h,36h,3ah,3eh
	.db	4,0ch,14h,1ch,24h,2ch,34h,3ch
	.db	44h,4ch,54h,5ch,64h,6ch,74h,7ch
	.db	8,18h,28h,38h,48h,58h,68h,78h
	.db	88h,98h,0a8h,0b8h,0c8h,0d8h,0e8h,0f8h
	.db	10h,30h,50h,70h,90h,0b0h,0d0h,0f0h
	.db	10h,30h,50h,70h,90h,0b0h,0d0h,0f0h
	.db	20h,60h,0a0h,0e0h,20h,60h,0a0h,0e0h
	.db	20h,60h,0a0h,0e0h,20h,60h,0a0h,0e0h
	.db	40h,0c0h,40h,0c0h,40h,0c0h,40h,0c0h
	.db	40h,0c0h,40h,0c0h,40h,0c0h,40h,0c0h
;
cmd_80_8f_silence_dac:
	clr	pin_dsp_busy
	jb	pin_dma_enablel,X08ab
	setb	tr0
	ljmp	wait_for_command
;
X08ab:	clr	pin_dma_enablel
X08ad:	jnb	pin_dav_dsp,X08ad
	movx	a,@r0
	mov	r5,a
X08b2:	jnb	pin_dav_dsp,X08b2
	movx	a,@r0
	mov	r6,a
	mov	timer_mode,#8
	setb	flag_dac_silenc
	ljmp	start_timer
;
cmd_90_92_94_96_auto_init_dma_hs:
	mov	autoinit_magic1,#55h
	mov	autoinit_magic2,#0aah
	clr	pin_dma_enablel
	clr	et0
	setb	tr0
	clr	tf0
X08cd:	mov	r5,ai_dma_len_l
	mov	r6,ai_dma_len_h
X08d1:	jnb	tf0,X08d1
	clr	tf0
	setb	pin_drequest
	clr	pin_drequest
X08da:	jnb	pin_dav_dsp,X08da
	movx	a,@r0
	mov	port_dac_out,a
	cjne	r5,#0,X08ed
	cjne	r6,#0,X08ec
	clr	pin_irequest
	setb	pin_irequest
	sjmp	X08cd
;
X08ec:	dec	r6
X08ed:	dec	r5
	sjmp	X08d1
;
cmd_91_93_95_97:
	mov	autoinit_magic1,#55h
	mov	autoinit_magic2,#0aah
	clr	pin_dma_enablel
	clr	et0
	setb	tr0
	clr	tf0
	mov	r5,ai_dma_len_l
	mov	r6,ai_dma_len_h
X0902:	jnb	tf0,X0902
	clr	tf0
	setb	pin_drequest
	clr	pin_drequest
X090b:	jnb	pin_dav_dsp,X090b
	movx	a,@r0
	mov	port_dac_out,a
	cjne	r5,#0,X091e
	cjne	r6,#0,X091d
	clr	pin_irequest
	setb	pin_irequest
	sjmp	X097d
;
X091d:	dec	r6
X091e:	dec	r5
	sjmp	X0902
;
cmd_98_9a_9c_9e_auto_init_adc_hs:
	mov	autoinit_magic1,#55h
	mov	autoinit_magic2,#0aah
	clr	pin_dma_enablel
	clr	et0
	setb	tr0
	clr	tf0
X092f:	mov	r5,ai_dma_len_l
	mov	r6,ai_dma_len_h
X0933:	jnb	tf0,X0933
	clr	tf0
	lcall	get_adc_sample
	setb	pin_drequest
	clr	pin_drequest
	cjne	r5,#0,X094c
	cjne	r6,#0,X094b
	clr	pin_irequest
	setb	pin_irequest
	sjmp	X092f
;
X094b:	dec	r6
X094c:	dec	r5
	sjmp	X0933
;
cmd_99_9b_9d_9f:
	mov	autoinit_magic1,#55h
	mov	autoinit_magic2,#0aah
	clr	pin_dma_enablel
	clr	et0
	setb	tr0
	clr	tf0
	mov	r5,ai_dma_len_l
	mov	r6,ai_dma_len_h
X0961:	jnb	tf0,X0961
	clr	tf0
	lcall	get_adc_sample
	setb	pin_drequest
	clr	pin_drequest
	cjne	r5,#0,X097a
	cjne	r6,#0,X0979
	clr	pin_irequest
	setb	pin_irequest
	sjmp	X097d
;
X0979:	dec	r6
X097a:	dec	r5
	sjmp	X0961
;
X097d:	clr	a
	mov	autoinit_magic1,a
	mov	autoinit_magic2,a
	clr	tr0
	setb	pin_dma_enablel
	clr	pin_dsp_busy
	ljmp	wait_for_command
;
cmd_d0_d2_halt_dma:
	clr	et0
	clr	tr0
	setb	pin_dma_enablel
	sjmp	bail_special_cmd
;
cmd_d1_enable_speaker:
	clr	pin_dsp_busy
	mov	port_dac_out,#0
	clr	pin_mute_en
	setb	speaker_status
	clr	a
X099d:	mov	port_dac_out,a
	inc	a
	mov	r3,#31h
X09a2:	djnz	r3,X09a2
	cjne	a,#81h,X099d
	sjmp	bail_special_cmd
;
cmd_d3_disable_speaker:
	clr	pin_dsp_busy
	mov	a,port_dac_out
X09ad:	mov	r3,#30h
X09af:	djnz	r3,X09af
	jz	X09b8
	mov	port_dac_out,a
	dec	a
	sjmp	X09ad
;
X09b8:	setb	pin_mute_en
	clr	speaker_status
	sjmp	bail_special_cmd
;
cmd_d4_d7_dc_df_dma_continue:
	clr	pin_dma_enablel
	setb	et0
	setb	tr0
	sjmp	bail_special_cmd
;
cmd_d8_d9_speaker_status:
	clr	a
	jb	pin_mute_en,X09cb
	cpl	a
X09cb:	jb	pin_dav_pc,X09cb
	movx	@r0,a
	sjmp	bail_special_cmd
;
cmd_da_db_exit_auto_init_dma:
	setb	misc_flags.2
bail_special_cmd:
	clr	pin_dsp_busy
	jnb	et0,X09da
	setb	tr0
X09da:	ljmp	wait_for_command
;
cmd_e0_dsp_ident:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X0a4c
X09e2:	jnb	pin_dav_dsp,X09e2
	movx	a,@r0
	cpl	a
X09e7:	jb	pin_dav_pc,X09e7
	movx	@r0,a
	ljmp	wait_for_command
;
cmd_e1_dsp_version:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X0a4c
	mov	a,#2
X09f5:	jb	pin_dav_pc,X09f5
	movx	@r0,a
	mov	a,#1
X09fb:	jb	pin_dav_pc,X09fb
	movx	@r0,a
	ljmp	wait_for_command
;
cmd_e2_e3_dsp_copyright:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X0a4c
X0a07:	jnb	pin_dav_dsp,X0a07
	movx	a,@r0
	setb	pin_dsp_busy
	clr	pin_dma_enablel
	xrl	a,secret_rotater
	add	a,secret_accum
	mov	secret_accum,a
	mov	a,secret_rotater
	rr	a
	rr	a
	mov	secret_rotater,a
	mov	a,secret_accum
X0a1d:	jb	pin_dav_pc,X0a1d
	movx	@r0,a
	setb	pin_drequest
	clr	pin_drequest
X0a25:	jb	pin_dav_pc,X0a25
	nop	
	setb	pin_dma_enablel
	clr	pin_dsp_busy
	ljmp	wait_for_command
;
cmd_e4_e7_write_test_reg:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X0a4c
X0a35:	jnb	pin_dav_dsp,X0a35
	movx	a,@r0
	mov	test_reg,a
	ljmp	wait_for_command
;
cmd_e8_ef_read_test_reg:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X0a4c
	mov	a,test_reg
X0a45:	jb	pin_dav_pc,X0a45
	movx	@r0,a
	ljmp	wait_for_command
;
X0a4c:	setb	tr0
	ljmp	wait_for_command
;
cmd_f0_sine_generator:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X0a4c
	mov	r0,#40h
	mov	dptr,#sine_table
X0a5b:	mov	a,r0
	movc	a,@a+dptr
	mov	@r0,a
	inc	r0
	cjne	r0,#80h,X0a5b
	mov	r1,#40h
	mov	r6,#8
	mov	th0,#0c2h
	mov	timer_mode,#0ch
	clr	pin_mute_en
	setb	et0
	setb	tr0
	ljmp	wait_for_command
;
cmd_f1_dsp_aux_status:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X0a4c
	mov	a,#0ffh
	mov	c,pin_mute_en
	mov	acc.0,c
	mov	c,pin_adc_comp
	mov	acc.5,c
	mov	c,pin_dav_pc
	mov	acc.6,c
	mov	c,pin_dav_dsp
	mov	acc.7,c
X0a8c:	jb	pin_dav_pc,X0a8c
	movx	@r0,a
	ljmp	wait_for_command
;
cmd_f2_f3_irq_request:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X0a4c
	clr	pin_irequest
	setb	pin_irequest
	ljmp	wait_for_command
;
cmd_f4_f7:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X0a4c
	mov	a,#0dah
	movx	@r0,a
	mov	a,#0f4h
X0aa9:	jb	pin_dav_pc,X0aa9
	movx	@r0,a
	ljmp	wait_for_command
;
cmd_f8_ff_dsp_aux2_status:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X0a4c
	mov	r0,#7fh
	mov	a,#55h
X0ab9:	mov	@r0,a
	cjne	@r0,#55h,X0ac9
	djnz	r0,X0ab9
	mov	r0,#7fh
	mov	a,#0aah
X0ac3:	mov	@r0,a
	cjne	@r0,#0aah,X0ac9
	djnz	r0,X0ac3
X0ac9:	mov	a,r0
	movx	@r0,a
	ljmp	wait_for_command
;
cmd_hi_table:
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_80_8f_silence_dac
;
	ajmp	cmd_90_92_94_96_auto_init_dma_hs
;
	ajmp	cmd_91_93_95_97
;
	ajmp	cmd_90_92_94_96_auto_init_dma_hs
;
	ajmp	cmd_91_93_95_97
;
	ajmp	cmd_90_92_94_96_auto_init_dma_hs
;
	ajmp	cmd_91_93_95_97
;
	ajmp	cmd_90_92_94_96_auto_init_dma_hs
;
	ajmp	cmd_91_93_95_97
;
	ajmp	cmd_98_9a_9c_9e_auto_init_adc_hs
;
	ajmp	cmd_99_9b_9d_9f
;
	ajmp	cmd_98_9a_9c_9e_auto_init_adc_hs
;
	ajmp	cmd_99_9b_9d_9f
;
	ajmp	cmd_98_9a_9c_9e_auto_init_adc_hs
;
	ajmp	cmd_99_9b_9d_9f
;
	ajmp	cmd_98_9a_9c_9e_auto_init_adc_hs
;
	ajmp	cmd_99_9b_9d_9f
;
	ajmp	cmd_a0_a3_b0_b3_c0_c3_disable_stereo_in
;
	ajmp	cmd_a0_a3_b0_b3_c0_c3_disable_stereo_in
;
	ajmp	cmd_a0_a3_b0_b3_c0_c3_disable_stereo_in
;
	ajmp	cmd_a0_a3_b0_b3_c0_c3_disable_stereo_in
;
	ajmp	cmd_a4_a7_b4_b7_c4_c7
;
	ajmp	cmd_a4_a7_b4_b7_c4_c7
;
	ajmp	cmd_a4_a7_b4_b7_c4_c7
;
	ajmp	cmd_a4_a7_b4_b7_c4_c7
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a0_a3_b0_b3_c0_c3_disable_stereo_in
;
	ajmp	cmd_a0_a3_b0_b3_c0_c3_disable_stereo_in
;
	ajmp	cmd_a0_a3_b0_b3_c0_c3_disable_stereo_in
;
	ajmp	cmd_a0_a3_b0_b3_c0_c3_disable_stereo_in
;
	ajmp	cmd_a4_a7_b4_b7_c4_c7
;
	ajmp	cmd_a4_a7_b4_b7_c4_c7
;
	ajmp	cmd_a4_a7_b4_b7_c4_c7
;
	ajmp	cmd_a4_a7_b4_b7_c4_c7
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a0_a3_b0_b3_c0_c3_disable_stereo_in
;
	ajmp	cmd_a0_a3_b0_b3_c0_c3_disable_stereo_in
;
	ajmp	cmd_a0_a3_b0_b3_c0_c3_disable_stereo_in
;
	ajmp	cmd_a0_a3_b0_b3_c0_c3_disable_stereo_in
;
	ajmp	cmd_a4_a7_b4_b7_c4_c7
;
	ajmp	cmd_a4_a7_b4_b7_c4_c7
;
	ajmp	cmd_a4_a7_b4_b7_c4_c7
;
	ajmp	cmd_a4_a7_b4_b7_c4_c7
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_a8_af_b8_bf_c8_cf_enable_stereo_in
;
	ajmp	cmd_d0_d2_halt_dma
;
	ajmp	cmd_d1_enable_speaker
;
	ajmp	cmd_d0_d2_halt_dma
;
	ajmp	cmd_d3_disable_speaker
;
	ajmp	cmd_d4_d7_dc_df_dma_continue
;
	ajmp	cmd_d4_d7_dc_df_dma_continue
;
	ajmp	cmd_d4_d7_dc_df_dma_continue
;
	ajmp	cmd_d4_d7_dc_df_dma_continue
;
	ajmp	cmd_d8_d9_speaker_status
;
	ajmp	cmd_d8_d9_speaker_status
;
	ajmp	cmd_da_db_exit_auto_init_dma
;
	ajmp	cmd_da_db_exit_auto_init_dma
;
	ajmp	cmd_d4_d7_dc_df_dma_continue
;
	ajmp	cmd_d4_d7_dc_df_dma_continue
;
	ajmp	cmd_d4_d7_dc_df_dma_continue
;
	ajmp	cmd_d4_d7_dc_df_dma_continue
;
	ajmp	cmd_e0_dsp_ident
;
	ajmp	cmd_e1_dsp_version
;
	ajmp	cmd_e2_e3_dsp_copyright
;
	ajmp	cmd_e2_e3_dsp_copyright
;
	ajmp	cmd_e4_e7_write_test_reg
;
	ajmp	cmd_e4_e7_write_test_reg
;
	ajmp	cmd_e4_e7_write_test_reg
;
	ajmp	cmd_e4_e7_write_test_reg
;
	ajmp	cmd_e8_ef_read_test_reg
;
	ajmp	cmd_e8_ef_read_test_reg
;
	ajmp	cmd_e8_ef_read_test_reg
;
	ajmp	cmd_e8_ef_read_test_reg
;
	ajmp	cmd_e8_ef_read_test_reg
;
	ajmp	cmd_e8_ef_read_test_reg
;
	ajmp	cmd_e8_ef_read_test_reg
;
	ajmp	cmd_e8_ef_read_test_reg
;
	ajmp	cmd_f0_sine_generator
;
	ajmp	cmd_f1_dsp_aux_status
;
	ajmp	cmd_f2_f3_irq_request
;
	ajmp	cmd_f2_f3_irq_request
;
	ajmp	cmd_f4_f7
;
	ajmp	cmd_f4_f7
;
	ajmp	cmd_f4_f7
;
	ajmp	cmd_f4_f7
;
	ajmp	cmd_f8_ff_dsp_aux2_status
;
	ajmp	cmd_f8_ff_dsp_aux2_status
;
	ajmp	cmd_f8_ff_dsp_aux2_status
;
	ajmp	cmd_f8_ff_dsp_aux2_status
;
	ajmp	cmd_f8_ff_dsp_aux2_status
;
	ajmp	cmd_f8_ff_dsp_aux2_status
;
	ajmp	cmd_f8_ff_dsp_aux2_status
;
	ajmp	cmd_f8_ff_dsp_aux2_status
;
timer_jump_table:
	ajmp	isr_dma_dac_8
;
	ajmp	isr_dma_dac_2
;
	ajmp	isr_dma_dac_4
;
	ajmp	isr_dma_dac_26
;
	ajmp	isr_silence_gen
;
	ajmp	isr_dma_adc_8
;
	ajmp	isr_sine_gen
;
	reti	
;
cmd_a0_a3_b0_b3_c0_c3_disable_stereo_in:
	ljmp	cmd_60_63_disable_stereo_in
;
cmd_a4_a7_b4_b7_c4_c7:
	ljmp	cmd_64_67
;
cmd_a8_af_b8_bf_c8_cf_enable_stereo_in:
	ljmp	cmd_68_6f_enable_stereo_in
;
finished_dma_op:
	clr	misc_flags.2
	clr	misc_flags.1
	clr	misc_flags.0
	clr	et0
	clr	tr0
	clr	pin_irequest
	setb	pin_irequest
	setb	pin_dma_enablel
	clr	pin_dsp_busy
	reti	
;
adc_dac8_auto_init_isr:
	mov	r5,ai_dma_len_l
	mov	r6,ai_dma_len_h
	clr	pin_irequest
	setb	pin_irequest
	clr	pin_dsp_busy
	reti	
;
adc_dac8_auto_once_isr:
	mov	r5,dma_len_l_cp
	mov	r6,dma_len_h_cp
	clr	misc_flags.1
	clr	misc_flags.0
	clr	pin_irequest
	setb	pin_irequest
	clr	pin_dsp_busy
	reti	
;
prep_next_autoinit_dma_adpcm:
	mov	r5,ai_dma_len_l
	mov	r6,ai_dma_len_h
	setb	pin_drequest
	clr	pin_drequest
X0c1b:	jnb	pin_dav_dsp,X0c1b
	movx	a,@r0
	mov	adpcm_buf,a
	clr	pin_irequest
	setb	pin_irequest
	clr	pin_dsp_busy
	reti	
;
prep_last_autoinit_dma_adpcm:
	mov	r5,dma_len_l_cp
	mov	r6,dma_len_h_cp
	clr	misc_flags.1
	clr	misc_flags.0
	setb	pin_drequest
	clr	pin_drequest
X0c34:	jnb	pin_dav_dsp,X0c34
	movx	a,@r0
	mov	adpcm_buf,a
	clr	pin_irequest
	setb	pin_irequest
	clr	pin_dsp_busy
	reti	
;
dac8_isr_jump_table:
	ajmp	dac8_default_isr
;
	ajmp	adc_dac8_auto_init_isr
;
	ajmp	adc_dac8_auto_once_isr
;
	ajmp	adc_dac8_auto_once_isr
;
	ajmp	dac8_default_isr
;
	ajmp	dac8_default_isr
;
	ajmp	dac8_default_isr
;
	ajmp	dac8_default_isr
;
dac2_isr_jump_table:
	ajmp	dac2_default_isr
;
	ajmp	dac2_auto_init_isr
;
	ajmp	dac2_auto_once_isr
;
	ajmp	dac2_auto_once_isr
;
	ajmp	dac2_default_isr
;
	ajmp	dac2_default_isr
;
	ajmp	dac2_default_isr
;
	ajmp	dac2_default_isr
;
dac4_isr_jump_table:
	ajmp	dac4_default_isr
;
	ajmp	dac4_auto_init_isr
;
	ajmp	dac4_auto_once_isr
;
	ajmp	dac4_auto_once_isr
;
	ajmp	dac4_default_isr
;
	ajmp	dac4_default_isr
;
	ajmp	dac4_default_isr
;
	ajmp	dac4_default_isr
;
dac26_isr_jump_table:
	ajmp	dac26_default_isr
;
	ajmp	dac26_auto_init_isr
;
	ajmp	dac26_auto_once_isr
;
	ajmp	dac26_auto_once_isr
;
	ajmp	dac26_default_isr
;
	ajmp	dac26_default_isr
;
	ajmp	dac26_default_isr
;
	ajmp	dac26_default_isr
;
adc8_isr_jump_table:
	ajmp	adc8_default_isr
;
	ajmp	adc_dac8_auto_init_isr
;
	ajmp	adc_dac8_auto_once_isr
;
	ajmp	adc_dac8_auto_once_isr
;
	ajmp	adc8_default_isr
;
	ajmp	adc8_default_isr
;
	ajmp	adc8_default_isr
;
	ajmp	adc8_default_isr
;
get_adc_sample:
	mov	port_dac_out,#80h
	nop	
	jnb	pin_adc_comp,X0c9a
	clr	pin_dac_7
X0c9a:	setb	pin_dac_6
	nop	
	jnb	pin_adc_comp,X0ca2
	clr	pin_dac_6
X0ca2:	setb	pin_dac_5
	nop	
	jnb	pin_adc_comp,X0caa
	clr	pin_dac_5
X0caa:	setb	pin_dac_4
	nop	
	jnb	pin_adc_comp,X0cb2
	clr	pin_dac_4
X0cb2:	setb	pin_dac_3
	nop	
	jnb	pin_adc_comp,X0cba
	clr	pin_dac_3
X0cba:	setb	pin_dac_2
	nop	
	jnb	pin_adc_comp,X0cc2
	clr	pin_dac_2
X0cc2:	setb	pin_dac_1
	nop	
	jnb	pin_adc_comp,X0cca
	clr	pin_dac_1
X0cca:	setb	pin_dac_0
	nop	
	jnb	pin_adc_comp,X0cd2
	clr	pin_dac_0
X0cd2:	mov	a,port_dac_out
X0cd4:	jb	pin_dav_pc,X0cd4
	movx	@r0,a
	ret	
;
timer_isr:
	jnb	use_timer_table,do_timer_jump
	inc	r7
	cjne	r7,#0,timerskip1
	inc	r5
	cjne	r5,#0,timerskip1
	inc	r6
timerskip1:
	mov	tl0,#17h
	mov	th0,#0fch
	reti	
;
do_timer_jump:
	setb	pin_dsp_busy
	mov	dptr,#timer_jump_table
	mov	a,timer_mode
	anl	a,#0eh
	jmp	@a+dptr
;
isr_dma_dac_8:
	jnb	pin_dav_dsp,X0cfc
	clr	pin_dsp_busy
	reti	
;
X0cfc:	setb	pin_drequest
	clr	pin_drequest
X0d00:	jnb	pin_dav_dsp,X0d00
	movx	a,@r0
	mov	port_dac_out,a
	cjne	r5,#0,X0d1a
	cjne	r6,#0,X0d19
	mov	a,misc_flags
	anl	a,#7
	rl	a
	mov	dptr,#dac8_isr_jump_table
	jmp	@a+dptr
;
dac8_default_isr:
	clr	flag_dma_dac_8
	ajmp	finished_dma_op
;
X0d19:	dec	r6
X0d1a:	dec	r5
	clr	pin_dsp_busy
	reti	
;
isr_dma_dac_2:
	jnb	pin_dav_dsp,X0d24
	clr	pin_dsp_busy
	reti	
;
X0d24:	dec	r3
	cjne	r3,#0,dac_2_process_sample
	cjne	r5,#0,X0d44
	cjne	r6,#0,X0d43
	mov	a,misc_flags
	anl	a,#7
	rl	a
	mov	dptr,#dac2_isr_jump_table
	jmp	@a+dptr
;
dac2_default_isr:
	clr	flag_dma_dac_2
	ajmp	finished_dma_op
;
dac2_auto_once_isr:
	mov	r3,#4
	ajmp	prep_last_autoinit_dma_adpcm
;
dac2_auto_init_isr:
	mov	r3,#4
	ajmp	prep_next_autoinit_dma_adpcm
;
X0d43:	dec	r6
X0d44:	dec	r5
	mov	r3,#4
	setb	pin_drequest
	clr	pin_drequest
X0d4b:	jnb	pin_dav_dsp,X0d4b
	movx	a,@r0
	mov	adpcm_buf,a
dac_2_process_sample:
	mov	a,adpcm_buf
	rl	a
	rl	a
	mov	adpcm_buf,a
	mov	a,r7
	anl	a,#7
	swap	a
	jnb	adpcm_buf.0,X0d60
	setb	acc.0
X0d60:	mov	dptr,#adpcm_table
	movc	a,@a+dptr
	jb	adpcm_buf.1,X0d6e
	add	a,r2
	jnc	X0d74
	mov	a,#0ffh
	sjmp	X0d74
;
X0d6e:	xch	a,r2
	clr	c
	subb	a,r2
	jnc	X0d74
	clr	a
X0d74:	mov	r2,a
	mov	port_dac_out,a
	jnb	adpcm_buf.0,X0d84
	cjne	r7,#5,X0d80
	clr	pin_dsp_busy
	reti	
;
X0d80:	inc	r7
	clr	pin_dsp_busy
	reti	
;
X0d84:	cjne	r7,#0,X0d8a
	clr	pin_dsp_busy
	reti	
;
X0d8a:	dec	r7
	clr	pin_dsp_busy
	reti	
;
isr_dma_dac_4:
	jnb	pin_dav_dsp,X0d94
	clr	pin_dsp_busy
	reti	
;
X0d94:	dec	r3
	cjne	r3,#0,dac_4_process_sample
	cjne	r5,#0,X0db4
	cjne	r6,#0,X0db3
	mov	a,misc_flags
	anl	a,#7
	rl	a
	mov	dptr,#dac4_isr_jump_table
	jmp	@a+dptr
;
dac4_default_isr:
	clr	flag_dma_dac_4
	ajmp	finished_dma_op
;
dac4_auto_once_isr:
	mov	r3,#2
	ajmp	prep_last_autoinit_dma_adpcm
;
dac4_auto_init_isr:
	mov	r3,#2
	ajmp	prep_next_autoinit_dma_adpcm
;
X0db3:	dec	r6
X0db4:	dec	r5
	mov	r3,#2
	setb	pin_drequest
	clr	pin_drequest
X0dbb:	jnb	pin_dav_dsp,X0dbb
	movx	a,@r0
	mov	adpcm_buf,a
dac_4_process_sample:
	mov	a,adpcm_buf
	swap	a
	mov	adpcm_buf,a
	anl	a,#7
	mov	adpcm_mag,a
	mov	a,r7
	anl	a,#3
	swap	a
	orl	a,adpcm_mag
	mov	dptr,#adpcm_table
	movc	a,@a+dptr
	jb	adpcm_buf.3,X0dde
	add	a,r2
	jnc	X0de4
	mov	a,#0ffh
	sjmp	X0de4
;
X0dde:	xch	a,r2
	clr	c
	subb	a,r2
	jnc	X0de4
	clr	a
X0de4:	mov	r2,a
	mov	port_dac_out,a
	mov	a,adpcm_mag
	jz	X0dfa
	cjne	a,#5,X0dee
X0dee:	jc	X0df3
	cjne	r7,#3,X0df6
X0df3:	clr	pin_dsp_busy
	reti	
;
X0df6:	inc	r7
	clr	pin_dsp_busy
	reti	
;
X0dfa:	cjne	r7,#0,X0e00
	clr	pin_dsp_busy
	reti	
;
X0e00:	dec	r7
	clr	pin_dsp_busy
	reti	
;
isr_dma_dac_26:
	jnb	pin_dav_dsp,X0e0a
	clr	pin_dsp_busy
	reti	
;
X0e0a:	dec	r3
	cjne	r3,#0,dac_26_process_sample
	cjne	r5,#0,X0e2a
	cjne	r6,#0,X0e29
	mov	a,misc_flags
	anl	a,#7
	rl	a
	mov	dptr,#dac26_isr_jump_table
	jmp	@a+dptr
;
dac26_default_isr:
	clr	flag_dma_dac_26
	ajmp	finished_dma_op
;
dac26_auto_once_isr:
	mov	r3,#3
	ajmp	prep_last_autoinit_dma_adpcm
;
dac26_auto_init_isr:
	mov	r3,#3
	ajmp	prep_next_autoinit_dma_adpcm
;
X0e29:	dec	r6
X0e2a:	dec	r5
	mov	r3,#3
	setb	pin_drequest
	clr	pin_drequest
X0e31:	jnb	pin_dav_dsp,X0e31
	movx	a,@r0
	mov	adpcm_buf,a
dac_26_process_sample:
	mov	a,adpcm_buf
	mov	adpcm_sign,a
	rl	a
	rl	a
	cjne	r3,#1,X0e44
	anl	a,#1
	sjmp	X0e49
;
X0e44:	rl	a
	mov	adpcm_buf,a
	anl	a,#3
X0e49:	mov	adpcm_mag,a
	mov	a,r7
	anl	a,#7
	swap	a
	orl	a,adpcm_mag
	mov	dptr,#adpcm_table
	movc	a,@a+dptr
	jb	adpcm_sign.7,X0e5f
	add	a,r2
	jnc	X0e65
	mov	a,#0ffh
	sjmp	X0e65
;
X0e5f:	xch	a,r2
	clr	c
	subb	a,r2
	jnc	X0e65
	clr	a
X0e65:	mov	r2,a
	mov	port_dac_out,a
	mov	a,adpcm_mag
	jz	X0e79
	cjne	a,#3,X0e72
	cjne	r7,#4,X0e75
X0e72:	clr	pin_dsp_busy
	reti	
;
X0e75:	inc	r7
	clr	pin_dsp_busy
	reti	
;
X0e79:	cjne	r7,#0,X0e7f
	clr	pin_dsp_busy
	reti	
;
X0e7f:	dec	r7
	clr	pin_dsp_busy
	reti	
;
isr_dma_adc_8:
	jnb	pin_dav_dsp,X0e89
	clr	pin_dsp_busy
	reti	
;
X0e89:	lcall	get_adc_sample
	setb	pin_drequest
	clr	pin_drequest
	cjne	r5,#0,X0eb8
	cjne	r6,#0,X0eb7
	mov	a,misc_flags
	anl	a,#7
	rl	a
	mov	dptr,#adc8_isr_jump_table
	jmp	@a+dptr
;
adc8_default_isr:
	clr	misc_flags.2
	clr	misc_flags.0
	clr	misc_flags.1
	clr	et0
	clr	tr0
X0ea9:	jb	pin_dav_pc,X0ea9
	clr	pin_irequest
	setb	pin_irequest
	clr	21h.2
	setb	pin_dma_enablel
	clr	pin_dsp_busy
	reti	
;
X0eb7:	dec	r6
X0eb8:	dec	r5
	clr	pin_dsp_busy
	reti	
;
isr_silence_gen:
	jnb	pin_dav_dsp,X0ec2
	clr	pin_dsp_busy
	reti	
;
X0ec2:	cjne	r5,#0,X0ed8
	cjne	r6,#0,X0ed7
	clr	flag_dac_silenc
	clr	et0
	clr	tr0
	clr	pin_irequest
	setb	pin_irequest
	setb	pin_dma_enablel
	clr	pin_dsp_busy
	reti	
;
X0ed7:	dec	r6
X0ed8:	dec	r5
	clr	pin_dsp_busy
	reti	
;
isr_sine_gen:
	mov	a,@r1
	mov	port_dac_out,a
	mov	a,r6
	add	a,r1
	cjne	a,#80h,X0ee4
X0ee4:	jc	X0ee8
	mov	a,#40h
X0ee8:
	mov	r1,a
	clr	pin_dsp_busy
	nop	            ; Next, this clever trick executes part of the copyright.
	add	a,r0        ; '('
	orl	29h,#31h    ; 'C)1'
	addc	a,r1    ; '9'
	addc	a,r1    ; '9'
	reti	        ; '2' (only this instruction does anything)
;
	.db	" Anchor Electronics Co.,"
	.db	0

.db 0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.org 0f80h
sine_table:
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh


;
;
;
	.org	0fc0h
;
	.db	80h,8ch,98h,0a4h,0b0h,0bbh,0c6h,0d0h
	.db	0d9h,0e2h,0e9h,0f0h,0f5h,0f9h,0fch,0feh
	.db	0ffh,0feh,0fch,0f9h,0f5h,0f0h,0e9h,0e2h
	.db	0d9h,0d0h,0c6h,0bbh,0b0h,0a4h,98h,8ch
	.db	80h,73h,67h,5bh,4fh,44h,39h,2fh
	.db	26h,1dh,16h,0fh,0ah,6,3,1
	.db	1,1,3,6,0ah,0fh,16h,1dh
	.db	26h,2fh,39h,44h,4fh,5bh,67h,73h
;
