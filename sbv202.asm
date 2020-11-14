; 8051 Disassembly of SB DSP version 2.02
; Reversed by @TubeTimeUS, 2020/11/13.
; Comments (C) TubeTime

;
; Register/Memory Equates
;
.EQU ram_samples_x2, 10h
.EQU ram_pb_count, 11h
.EQU ram_pb_count2, 12h
.EQU ram_pb_unused, 13h
.EQU ram_loops2, 14h
.EQU ram_loops, 15h
.EQU ram_pb_unused2, 16h
.EQU rb2r7, 17h
.EQU time_constant, 18h
.EQU rb3r1, 19h
.EQU ram_smps_left, 1ah
.EQU length_low, 1bh
.EQU length_high, 1ch
.EQU dma_blk_len_lo, 1dh
.EQU dma_blk_len_hi, 1eh
.EQU command_byte, 20h
.EQU len_left_lo, 21h
.EQU len_left_hi, 22h
.EQU status_register, 23h
.EQU dsp_dma_id0, 25h
.EQU dsp_dma_id1, 26h
.EQU vector_low, 2ch
.EQU vector_high, 2dh
.EQU warmboot_magic1, 2eh
.EQU warmboot_magic2, 2fh

;
; SFR Equates
;
.EQU port_dac_out, 90h

;
; SFR bit Equates
;
.EQU pin_dac_0, 90h
.EQU pin_dac_1, 91h
.EQU pin_dac_2, 92h
.EQU pin_dac_3, 93h
.EQU pin_dac_4, 94h
.EQU pin_dac_5, 95h
.EQU pin_dac_6, 96h
.EQU pin_dac_7, 97h
.EQU pin_mute_en, 0a0h
.EQU pin_adc_comp, 0a5h
.EQU pin_dav_pc, 0a6h
.EQU pin_dav_dsp, 0a7h
.EQU pin_irequest, 0b2h
.EQU pin_dsp_busy, 0b3h
.EQU pin_dma_enablel, 0b4h
.EQU pin_drequest, 0b5h

;
; Memory bit Equates
;
.EQU command_byte_0, 0
.EQU command_byte_1, 1
.EQU command_byte_2, 2
.EQU command_byte_3, 3
.EQU command_byte_4, 4
.EQU command_byte_5, 5
.EQU command_byte_6, 6
.EQU command_byte_7, 7
.EQU spkr_on, 18h
.EQU mode_dma_adc, 1ah
.EQU mode_silence, 1bh
.EQU mode_adpcm2, 1ch
.EQU mode_adpcm26, 1dh
.EQU mode_adpcm4, 1eh
.EQU mode_dma_dac, 1fh
.EQU cmd_avail, 20h
.EQU dma_mode_on, 21h
.EQU dma_autoinit_on, 22h
.EQU midi_timestamp, 23h
.EQU autoinit_exit, 24h
.EQU high_speed, 25h
.EQU record_mode, 26h

	.org	0

RESET:	ljmp	start

	.db	0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh

	.org	0bh
;
; Timer/Counter 0 Interrupt Vector
;
TF0_VECTOR:
	; High speed flag indicates fast sample playback/record mode
	jb	high_speed,hs_int
	; MIDI timestamp flag 
	jb	midi_timestamp,midi_timestamp_int

	; Perform housekeeping and jump to appropriate handler for the current
	; DSP mode.
	setb	pin_dsp_busy
	push	acc
	push	dpl
	push	dph
	mov	dpl,vector_low
	mov	dph,vector_high
	clr	a
	jmp	@a+dptr
;
; Handles MIDI timestamp counter.
;
midi_timestamp_int:
	inc	r5
	cjne	r5,#0,X002a
	inc	r6
	cjne	r6,#0,X002a
	inc	r7
X002a:	mov	tl0,#17h
	mov	th0,#0fch
	reti	
;
; Handle fast sample playback/record modes. These did not exist in the
; original SB firmware and were added later, removing interrupt overhead
; to allow for higher sample rates.
;
hs_int:
	; Check if we are in record mode
	jb	record_mode,get_adc_sample
	; Ask host PC for a sample
	setb	pin_drequest
	clr	pin_drequest
	; Wait for sample to arrive
X0038:	jnb	pin_dav_dsp,X0038
	; Read the mailbox and forward the sample to the DAC
	movx	a,@r0
	mov	port_dac_out,a
	; Check if we have more samples to output
	cjne	r6,#0,X0064
	cjne	r7,#0,X0063
	; We ran out of samples to play back, so trigger an interrupt to let
	; the host PC know about it.
	clr	pin_irequest
	setb	pin_irequest
	; Check for autoinit mode (command 91h)
	jb	command_byte_0,X0052
	; Reinitialize the sample counter to our DMA block length
	mov	r6,dma_blk_len_lo
	mov	r7,dma_blk_len_hi
	ljmp	X0065
;
X0052:	
	; Reset the timer
	clr	et0
	clr	tr0
	; Disable DMA
	setb	pin_dma_enablel
	; Clear warm boot magic number
	mov	warmboot_magic1,#0
	mov	warmboot_magic2,#0
	; Turn off high speed mode
	clr	high_speed
	ljmp	X0065

	; Decrement sample counter
X0063:	dec	r7
X0064:	dec	r6
X0065:	reti	
;
; Collects a sample from the microphone input. This routine uses a SAR
; algorithm (successive approximation).
;
get_adc_sample:
	; Set the DAC to center code
	mov	port_dac_out,#80h
	nop	
	nop
	; Check the analog comparator output	
	jnb	pin_adc_comp,X0070
	clr	pin_dac_7		; Below 80h
X0070:	setb	pin_dac_6		; Above 80h
	nop	
	nop
	; Repeat for the remaining bits	
	jnb	pin_adc_comp,X0079
	clr	pin_dac_6
X0079:	setb	pin_dac_5
	nop	
	jnb	pin_adc_comp,X0081
	clr	pin_dac_5
X0081:	setb	pin_dac_4
	nop	
	jnb	pin_adc_comp,X0089
	clr	pin_dac_4
X0089:	setb	pin_dac_3
	nop	
	jnb	pin_adc_comp,X0091
	clr	pin_dac_3
X0091:	setb	pin_dac_2
	nop	
	jnb	pin_adc_comp,X0099
	clr	pin_dac_2
X0099:	setb	pin_dac_1
	nop	
	jnb	pin_adc_comp,X00a1
	clr	pin_dac_1
X00a1:	setb	pin_dac_0
	nop	
	jnb	pin_adc_comp,X00a9
	clr	pin_dac_0
	; the DAC output contains the acquired analog voltage now
X00a9:	mov	a,port_dac_out
	; Wait for the mailbox to become empty
X00ab:	jb	pin_dav_pc,X00ab
	; Write sample out to mailbox
	movx	@r0,a
	; Request DMA from the host PC
	setb	pin_drequest
	clr	pin_drequest
	; Check sample counter
	cjne	r6,#0,X00d9
	cjne	r7,#0,X00d8
	; Trigger interrupt if our sample count hit zero
	clr	pin_irequest
	setb	pin_irequest
	; Check if we are in auto-init DMA mode (command 99h)
	jb	command_byte_0,X00c7
	; Reset sample counter and start again
	mov	r6,dma_blk_len_lo
	mov	r7,dma_blk_len_hi
	ljmp	X00da
;
X00c7:	
	; Regular DMA
	; Clear timer, turn off DMA, clear warm boot magic number, and clear
	; high speed mode.
	clr	et0
	clr	tr0
	setb	pin_dma_enablel
	mov	warmboot_magic1,#0
	mov	warmboot_magic2,#0
	clr	high_speed
	ljmp	X00da

	; Decrement sample counter
X00d8:	dec	r7
X00d9:	dec	r6
X00da:	reti	

;
; Programmable interrupt vectors (non-high-speed)
; These are set up by placing their start address in vector_low and vector_high
; so that they will be triggered when the timer overflows.
;

;
; Vector for DAC playback, 8-bit DMA mode
;
vector_dma_dac_8:
	; Is the mailbox already full?
	jnb	pin_dav_dsp,X00e3
	; Then we have a command waiting
	setb	cmd_avail
	ljmp	vector_dma_dac_8_end
;
X00e3:	
	; Ask host PC for a sample
	setb	pin_drequest
	clr	pin_drequest
	; Wait for the data to arrive
X00e7:	jnb	pin_dav_dsp,X00e7
	; Copy it over to the DAC
	movx	a,@r0
	mov	port_dac_out,a
	; Check the remaining number of samples
	clr	a
	cjne	a,len_left_lo,X0132
	cjne	a,len_left_hi,X0130
	; If we are supposed to exit auto-init DMA, then do that.
	jb	autoinit_exit,X00fd
	; Are we in regular DMA mode? Then handle that.
	jb	dma_mode_on,X011f
	; Auto init is set, so handle that.
	jb	dma_autoinit_on,X0112
X00fd:	
	; Clean up after the end of auto-init DMA
	clr	dma_mode_on
	clr	dma_autoinit_on
	clr	autoinit_exit
	clr	et0
	clr	tr0
	; Trigger host PC interrupt since we are done.
	clr	pin_irequest
	setb	pin_irequest
	clr	mode_dma_dac
	; Turn off DMA
	setb	pin_dma_enablel
	; Done!
	ljmp	vector_dma_dac_8_end
;
X0112:
	; For ongoing auto-init DMA, loop back to the beginning
	; Reset the sample count
	mov	len_left_lo,dma_blk_len_lo
	mov	len_left_hi,dma_blk_len_hi
	; Trigger host PC interrupt
	clr	pin_irequest
	setb	pin_irequest
	; Return and continue playback
	ljmp	vector_dma_dac_8_end
;
X011f:	
	; Clean up after standard DMA mode
	clr	dma_autoinit_on
	clr	dma_mode_on
	; Reset sample count
	mov	len_left_lo,length_low
	mov	len_left_hi,length_high
	; Trigger host PC interrupt
	clr	pin_irequest
	setb	pin_irequest
	ljmp	vector_dma_dac_8_end

	; Decrement sample counter
X0130:	dec	len_left_hi
X0132:	dec	len_left_lo
vector_dma_dac_8_end:
	; We are done, so clear the busy bit and wait for the next command.
	clr	pin_dsp_busy
	pop	dph
	pop	dpl
	pop	acc
	reti	

;
; Vector for DAC playback, 2-bit ADPCM
;

; Register use:
; r3 = Packed samples remaining in current data byte
; r6 = Current data byte (contains 4 packed samples)
vector_dma_dac_adpcm2:
	; Is there a byte waiting in the mailbox already?
	jnb	pin_dav_dsp,X0145
	; Then it is a command, so quit.
	setb	cmd_avail
	ljmp	vector_dma_dac_adpcm2_end

	; First we need figure out if we need to request another
	; byte of sample data. r3 is that counter
X0145:	dec	r3
	; If it hits 0, then we need to get more data.
	cjne	r3,#0,vector_dma_dac_adpcm2_shiftin
	; Do we have more data bytes left to collect?
	clr	a
	cjne	a,len_left_lo,X01a4
	cjne	a,len_left_hi,X01a2
	; No more data bytes, so end playback depending on the mode that
	; we are in.
	jb	autoinit_exit,X0159
	jb	dma_mode_on,X0186
	jb	dma_autoinit_on,X016e
X0159:
	; End auto-init playback mode.
	clr	dma_mode_on
	clr	dma_autoinit_on
	clr	autoinit_exit
	clr	et0
	clr	tr0
	clr	pin_irequest
	setb	pin_irequest
	clr	mode_adpcm2
	setb	pin_dma_enablel
	ljmp	vector_dma_dac_adpcm2_end
;
X016e:	
	; For auto init DMA mode, reset sample counter, restart playback at the
	; beginning.
	mov	len_left_lo,dma_blk_len_lo
	mov	len_left_hi,dma_blk_len_hi
	; Ask for data byte
	setb	pin_drequest
	clr	pin_drequest
	; Wait for it to arrive
X0178:	jnb	pin_dav_dsp,X0178
	movx	a,@r0
	; Load it into r6 (data buffer)
	mov	r6,a
	; Since this is 2-bit ADPCM, each byte contains 4 samples.
	mov	r3,#4
	; Trigger host PC interrupt
	clr	pin_irequest
	setb	pin_irequest
	ljmp	vector_dma_dac_adpcm2_end
;
X0186:
	; Exit after finishing standard DMA output mode
	clr	dma_autoinit_on
	clr	dma_mode_on
	mov	len_left_lo,length_low
	mov	len_left_hi,length_high
	setb	pin_drequest
	clr	pin_drequest
X0194:	jnb	pin_dav_dsp,X0194
	movx	a,@r0
	mov	r6,a
	mov	r3,#4
	clr	pin_irequest
	setb	pin_irequest
	ljmp	vector_dma_dac_adpcm2_end

	; OK, since we are in the middle of playback, and we are supposed to
	; collect another data byte, the first thing to do is decrement the
	; bytes-left counter
X01a2:	dec	len_left_hi
X01a4:	dec	len_left_lo
	; We are reading in 4 samples at a time.
	mov	r3,#4
	; Ask for the samples from the host PC by triggering DMA.
	setb	pin_drequest
	clr	pin_drequest
	; Wait for the byte to arrive
X01ac:	jnb	pin_dav_dsp,X01ac
	; Copy it into our sample buffer
	movx	a,@r0
	mov	r6,a
vector_dma_dac_adpcm2_shiftin:
	; Decode the current sample
	lcall	adpcm_2_decode
vector_dma_dac_adpcm2_end:
	clr	pin_dsp_busy
	pop	dph
	pop	dpl
	pop	acc
	reti	

;
; Vector for DAC playback, 4-bit ADPCM
;

; Register use:
; r3 = Packed samples remaining in current data byte
; r6 = Current data byte (contains 4 packed samples)
vector_dma_dac_adpcm4:
	; If there's a byte waiting in the mailbox already, then it is a
	; a command, so go back to process that.
	jnb	pin_dav_dsp,X01c5
	setb	cmd_avail
	ljmp	vector_dma_dac_adpcm4_end
	; Figure out if we need to request another byte of sample data.
X01c5:	dec	r3
	; If r3 hits 0, then we need more data.
	cjne	r3,#0,vector_dma_dac_adpcm4_shiftin
	; Check to see if we have any remaining data bytes to collect.
	clr	a
	cjne	a,len_left_lo,X0224
	cjne	a,len_left_hi,X0222
	; We do not, so end playback depending on the mode that we are in.
	jb	autoinit_exit,X01d9
	jb	dma_mode_on,X0206
	jb	dma_autoinit_on,X01ee
X01d9:
	; Exit auto-init DMA mode.
	clr	dma_mode_on
	clr	dma_autoinit_on
	clr	autoinit_exit
	clr	et0
	clr	tr0
	clr	pin_irequest
	setb	pin_irequest
	clr	mode_adpcm4
	setb	pin_dma_enablel
	ljmp	vector_dma_dac_adpcm4_end

X01ee:
	; Ongoing auto-init DMA, so reset back to the beginning of the buffer
	; and continue playback from the start.
	mov	len_left_lo,dma_blk_len_lo
	mov	len_left_hi,dma_blk_len_hi
	setb	pin_drequest
	clr	pin_drequest
X01f8:	jnb	pin_dav_dsp,X01f8
	movx	a,@r0
	mov	r6,a
	; We have 2 packed samples per byte
	mov	r3,#2
	; Let the host PC know by triggering an interrupt
	clr	pin_irequest
	setb	pin_irequest
	ljmp	vector_dma_dac_adpcm4_end

X0206:
	; End of regular DMA playback, so clear flags, etc.
	clr	dma_autoinit_on
	clr	dma_mode_on
	mov	len_left_lo,length_low
	mov	len_left_hi,length_high
	setb	pin_drequest
	clr	pin_drequest
X0214:	jnb	pin_dav_dsp,X0214
	movx	a,@r0
	mov	r6,a
	mov	r3,#2
	clr	pin_irequest
	setb	pin_irequest
	ljmp	vector_dma_dac_adpcm4_end

	; OK, since we are in the middle of playback, and we are supposed to
	; collect another data byte, the first thing to do is decrement the
	; bytes-left counter
X0222:	dec	len_left_hi
X0224:	dec	len_left_lo
	; We are reading in 2 samples at a time.
	mov	r3,#2
	; Ask for the samples from the host PC by triggering DMA.
	setb	pin_drequest
	clr	pin_drequest
	; Wait for the byte to arrive
X022c:	jnb	pin_dav_dsp,X022c
	; Copy it into our sample buffer
	movx	a,@r0
	mov	r6,a
vector_dma_dac_adpcm4_shiftin:
	; Decode the current sample
	lcall	adpcm_4_decode
vector_dma_dac_adpcm4_end:
	clr	pin_dsp_busy
	pop	dph
	pop	dpl
	pop	acc
	reti	

;
; Vector for DAC playback, 2.6-bit ADPCM
; (I bet you can't wait to see how the fractional bit works!)
;

; Register use:
; r3 = Packed samples remaining in current data byte
; r6 = Current data byte (contains 2.6 packed samples)
vector_dma_dac_adpcm2_6:
	; If there's a byte waiting in the mailbox already, then it is a
	; a command, so go back to process that.
	jnb	pin_dav_dsp,X0245
	setb	cmd_avail
	ljmp	vector_dma_dac_adpcm2_6_end
	; Figure out if we need to request another byte of sample data.
X0245:	dec	r3
	; If r3 hits 0, then we need more data.
	cjne	r3,#0,vector_dma_dac_adpcm2_6_shiftin
	; Check to see if we have any remaining data bytes to collect.
	clr	a
	cjne	a,len_left_lo,X02a4
	cjne	a,len_left_hi,X02a2
	; We do not, so end playback depending on the mode that we are in.
	jb	autoinit_exit,X0259
	jb	dma_mode_on,X0286
	jb	dma_autoinit_on,X026e
X0259:	
	; Exit auto-init DMA mode.
	clr	dma_mode_on
	clr	dma_autoinit_on
	clr	autoinit_exit
	clr	et0
	clr	tr0
	clr	pin_irequest
	setb	pin_irequest
	clr	mode_adpcm26
	setb	pin_dma_enablel
	ljmp	vector_dma_dac_adpcm2_6_end

X026e:	
	; Ongoing auto-init DMA, so reset back to the beginning of the buffer
	; and continue playback from the start.
	mov	len_left_lo,dma_blk_len_lo
	mov	len_left_hi,dma_blk_len_hi
	setb	pin_drequest
	clr	pin_drequest
X0278:	jnb	pin_dav_dsp,X0278
	movx	a,@r0
	mov	r6,a
	; We have 3 packed samples per byte
	mov	r3,#3
	; Let the host PC know by triggering an interrupt
	clr	pin_irequest
	setb	pin_irequest
	ljmp	vector_dma_dac_adpcm2_6_end

X0286:	
	; End of regular DMA playback, so clear flags, etc.
	clr	dma_autoinit_on
	clr	dma_mode_on
	mov	len_left_lo,length_low
	mov	len_left_hi,length_high
	setb	pin_drequest
	clr	pin_drequest
X0294:	jnb	pin_dav_dsp,X0294
	movx	a,@r0
	mov	r6,a
	mov	r3,#3
	clr	pin_irequest
	setb	pin_irequest
	ljmp	vector_dma_dac_adpcm2_6_end

	; OK, since we are in the middle of playback, and we are supposed to
	; collect another data byte, the first thing to do is decrement the
	; bytes-left counter
X02a2:	dec	len_left_hi
X02a4:	dec	len_left_lo
	; We are reading in 3 samples at a time (2 full and 1 partial).
	mov	r3,#3
	; Ask for the samples from the host PC by triggering DMA.
	setb	pin_drequest
	clr	pin_drequest
	; Wait for the byte to arrive
X02ac:	jnb	pin_dav_dsp,X02ac
	; Copy it into our sample buffer
	movx	a,@r0
	mov	r6,a
vector_dma_dac_adpcm2_6_shiftin:
	; Decode the current sample
	lcall	adpcm_2_6_decode
vector_dma_dac_adpcm2_6_end:
	clr	pin_dsp_busy
	pop	dph
	pop	dpl
	pop	acc
	reti	
;
; Vector for DAC playback of silence. (Yes, it has its own vector.)
;
vector_dac_silence:
	; If there's a byte waiting in the mailbox already, then it is a
	; a command, so go back to process that.
	jnb	pin_dav_dsp,X02c5
	setb	cmd_avail
	ljmp	vector_dac_silence_end
X02c5:	
	; Check to see if we have any remaining samples to play.
	clr	a
	cjne	a,len_left_lo,X02dd
	cjne	a,len_left_hi,X02db
	; We do not, so end this playback operation.
	clr	et0
	clr	tr0
	clr	pin_irequest
	setb	pin_irequest
	clr	mode_silence
	setb	pin_dma_enablel
	ljmp	vector_dac_silence_end

	; Decrement the samples remaining counter.
X02db:	dec	len_left_hi
X02dd:	dec	len_left_lo
	; Normally we would request samples from the host PC, but in this case
	; we are playing silence, so we never request data nor do we update the
	; DAC output.
vector_dac_silence_end:
	clr	pin_dsp_busy
	pop	dph
	pop	dpl
	pop	acc
	reti	

;
; Vector for 8-bit DMA recording.
;
vector_dma_adc:
	; If there's a byte waiting in the mailbox already, then it is a
	; a command, so go back to process that.
	jnb	pin_dav_dsp,X02f0
	setb	cmd_avail
	ljmp	vector_dma_adc_end

X02f0:	
	; Acquire a sample using a SAR algorithm.
	; Start off the DAC at half code, then go through bit-by-bit, checking
	; the output of the analog comparator to decide how to change the DAC
	; output.
	mov	port_dac_out,#80h
	nop	
	nop	
	jnb	pin_adc_comp,X02fa
	clr	pin_dac_7
X02fa:	setb	pin_dac_6
	nop	
	nop	
	jnb	pin_adc_comp,X0303
	clr	pin_dac_6
X0303:	setb	pin_dac_5
	nop	
	jnb	pin_adc_comp,X030b
	clr	pin_dac_5
X030b:	setb	pin_dac_4
	nop	
	jnb	pin_adc_comp,X0313
	clr	pin_dac_4
X0313:	setb	pin_dac_3
	nop	
	jnb	pin_adc_comp,X031b
	clr	pin_dac_3
X031b:	setb	pin_dac_2
	nop	
	jnb	pin_adc_comp,X0323
	clr	pin_dac_2
X0323:	setb	pin_dac_1
	nop	
	jnb	pin_adc_comp,X032b
	clr	pin_dac_1
X032b:	setb	pin_dac_0
	nop	
	jnb	pin_adc_comp,X0333
	clr	pin_dac_0
	; We have finishing acquiring the sample, which is now contained in the
	; DAC output register.
X0333:	mov	a,port_dac_out
	; Wait for the mailbox to empty out (PC must read any stale data first)
X0335:	jb	pin_dav_pc,X0335
	; Now place the sample into the mailbox.
	movx	@r0,a
	; And request a DMA transfer from the host PC.
	setb	pin_drequest
	clr	pin_drequest
	; Check the sample counter to see if we have any more samples to record
	clr	a
	cjne	a,len_left_lo,X0385
	cjne	a,len_left_hi,X0383
	; We do not, so end recording in the way required by our current
	; recording mode.
	jb	autoinit_exit,X034d
	jb	dma_mode_on,X0372
	jb	dma_autoinit_on,X0365
X034d:	
	; We are exiting auto-init DMA mode.
	clr	dma_mode_on
	clr	dma_autoinit_on
	clr	autoinit_exit
	clr	et0
	clr	tr0
	; Wait for host PC to grab the last remaining sample.
X0357:	jb	pin_dav_pc,X0357
	; Trigger the host PC interrupt to tell it that we are done.
	clr	pin_irequest
	setb	pin_irequest
	clr	mode_dma_adc
	setb	pin_dma_enablel
	ljmp	vector_dma_adc_end
;
X0365:	
	; We are in auto-init DMA mode, so reset the sample counter and
	; continue recording samples starting at the beginning again.
	mov	len_left_lo,dma_blk_len_lo
	mov	len_left_hi,dma_blk_len_hi
	; Let the host PC know we hit the end of the buffer by triggering an
	; interrupt.
	clr	pin_irequest
	setb	pin_irequest
	ljmp	vector_dma_adc_end

X0372:	
	; End normal DMA mode.
	clr	dma_autoinit_on
	clr	dma_mode_on
	mov	len_left_lo,length_low
	mov	len_left_hi,length_high
	clr	pin_irequest
	setb	pin_irequest
	ljmp	vector_dma_adc_end

	; We still have samples left to record, so decrement the sample counter
	; and continue.
X0383:	dec	len_left_hi
X0385:	dec	len_left_lo
vector_dma_adc_end:
	clr	pin_dsp_busy
	pop	dph
	pop	dpl
	pop	acc
	reti	

;
; Vector for DAC playback from onboard SRAM
; (Formerly undocumented playback mode!)
;

; Register use:
; r1 = pointer to SRAM for current sample
vector_cmd_ram_playback:
	; Get sample from SRAM, send it out to the DAC.
	mov	a,@r1
	mov	port_dac_out,a
	; Move the sample pointer to the next sample in SRAM.
	inc	r1
	; Do we have any samples left to play back?
	djnz	ram_smps_left,vector_cmd_ram_playback_end
	; We do not, so reset the sample pointer.
	mov	r1,#40h
	; Decrement our playback loop counter. This is the number of times we
	; are supposed to play back the SRAM buffer.
	djnz	ram_loops,X039f
	mov	ram_loops,ram_pb_count2
X039f:	djnz	ram_loops2,vector_cmd_ram_playback_end
	; Playback loop counter reached zero, so end playback.
	clr	tr0
	clr	et0
vector_cmd_ram_playback_end:
	clr	pin_dsp_busy
	pop	dph
	pop	dpl
	pop	acc
	reti	
;
; Vector for sine wave playback
;

; Register use:
; r1 = pointer to sine wave table in SRAM (from 0x40 to 0x7F)
; r7 = increment value for table pointer

; Note: this algorithm attempts to implement some sort of DDS by using the r1
; register as a phase accumulator. However, the wraparound checks seem to be
; broken.
vector_sine:
	; Get sample from ROM, send it out to the DAC.
	mov	a,@r1
	mov	port_dac_out,a
	; Calculate where in the table to fetch the next sample from.
	mov	a,r7
	add	a,r1
	; Bounds check.
	cjne	a,#7fh,X03ba
	ljmp	X03bc
;
X03ba:	jnc	X03c0
X03bc:	
	; Carry bit set (add operation overflowed) or the value was equal to
	; 7f, so update pointer to the new value.
	mov	r1,a
	ljmp	X03c2
;
X03c0:	
	; Carry bit not set, so we reset the pointer to zero.
	mov	r1,#40h
X03c2:	clr	pin_dsp_busy
	pop	dph
	pop	dpl
	pop	acc
	reti	
;
; **********************
; Start: Where we begin.
; **********************
;
start:	
	; We are busy right now (this bit can be read by the host PC in the
	; status register).
	setb	pin_dsp_busy
	; Configure the chip
	setb	pt0
	mov	sp,#30h
	clr	pin_drequest
	setb	pin_dma_enablel
	setb	wr
	setb	rd
	mov	scon,#42h
	mov	th1,#0feh
	mov	tl1,#0feh
	mov	tmod,#22h
	mov	pcon,#80h
	setb	tr1
	setb	ren
	; Check for the warm boot magic number
	mov	a,#34h
	cjne	a,warmboot_magic1,cold_boot
	mov	a,#12h
	cjne	a,warmboot_magic2,cold_boot
	; We are in a warm boot situation, so first off, clear the magic
	; number.
	mov	warmboot_magic1,#0
	mov	warmboot_magic2,#0
	; Is the speaker on?
	jnb	spkr_on,warm_boot
	; Then set the DAC to half code and turn off mute.
	mov	port_dac_out,#80h
	clr	pin_mute_en
	ljmp	warm_boot

;
; Cold boot startup.
;
cold_boot:
	; DAC set to half code.
	mov	port_dac_out,#80h
	; Initialize a bunch of variables.
	mov	rb2r7,#80h
	mov	ram_loops,#0
	mov	r7,#2
	mov	time_constant,#9ch
	mov	dsp_dma_id0,#0aah
	mov	dsp_dma_id1,#96h
	mov	r0,#40h
	mov	r1,#40h
	mov	r4,#40h
	mov	dma_blk_len_lo,#0ffh
	mov	dma_blk_len_hi,#7
	mov	status_register,#0
; Warm boot, so we skipped over some initialization.
warm_boot:
	; Configure the timer period based on our stored time constant (aka
	; sample rate).
	mov	a,time_constant
	mov	th0,a
	mov	tl0,a
	mov	24h,#0
	mov	r3,#0
	setb	ea
	clr	pin_dsp_busy
	mov	a,#0aah
	; Wait for mailbox to empty out.
X043c:	jb	pin_dav_pc,X043c
	; Then write 0xaa (reset successful) into the mailbox.
	movx	@r0,a

;
; Check for incoming commands. This is the start of the command monitoring
; loop, where we read commands, dispatch them, and then return back here.
;
check_cmd:
	; cmd_avail can be set in an interrupt handler in the case that we
	; receive a command while playback or recording is going on.
	jb	cmd_avail,X0446
	; Wait for the host PC to write a command to the mailbox.
wait_for_cmd:
	jnb	pin_dav_dsp,wait_for_cmd
X0446:	
	; Shut off the timer to pause any current playback/recording operation.
	clr	tr0
	; We are busy running a command, so update the status bit.
	setb	pin_dsp_busy
	clr	cmd_avail
	; Get the command from the mailbox.
	movx	a,@r0
	mov	command_byte,a
	; Fetch the most significant 4 bits, which represent the command group.
	swap	a
	anl	a,#0fh
	; Dispatch ordinary commands
	cjne	a,#0dh,dispatch_cmd
	; The command MSB was 0dh, so dispatch the miscellaneous command group.
	lcall	cmdg_misc
	jnb	et0,wait_for_cmd
	setb	tr0
	sjmp	wait_for_cmd
;
; Dispatches a command.
;
dispatch_cmd:
	; Look up the command group (4 MSBs of command byte) in the table of
	; major commands.
	mov	dptr,#table_major_cmds
	; Read the 8-bit offset for the current major command group.
	movc	a,@a+dptr
	; Jump to the table's address plus the offset we looked up.
	jmp	@a+dptr

table_major_cmds:
	.db	5ah,11h,1ah,1fh,35h,3dh,55h,14h
	.db	45h,17h,55h,55h,55h,55h,4dh,2dh
	.db	55h
; 11h: command group 1
cmdg_dac:
	ljmp	cmdg_dac_e
; 14h: command group 7
cmdg_dac2:
	ljmp	cmdg_dac2_e
; 17h: command group 9
cmdg_hs:
	ljmp	cmdg_hs_e
; 1ah: command group 2
cmdg_adc:
	clr	pin_dsp_busy
	ljmp	cmdg_adc_e
; 1fh: command group 3
cmdg_midi:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,X048b
	ljmp	do_midi_cmd
X048b:	
	; During an existing DMA operation (playback/recording) we can only
	; run the MIDI write/poll command and no others.
	jnb	command_byte_3,continue_dma_op
	ljmp	do_midi_cmd
; 2dh: command group F
cmdg_aux:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,continue_dma_op
	ljmp	cmdg_aux_e
; 35h: command group 4
cmdg_setup:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,continue_dma_op
	ljmp	cmdg_setup_e
; 3dh: command group 5
cmdg_ram_playback:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,continue_dma_op
	ljmp	cmdg_ram_playback_e
; 45h: command group 8
cmdg_silence:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,continue_dma_op
	ljmp	cmdg_silence_e
; 4dh: command group E
cmdg_ident:
	clr	pin_dsp_busy
	jnb	pin_dma_enablel,continue_dma_op
	ljmp	cmd_ident_e
; 55h: command groups 6, A, B, C, and D are unimplemented.
cmdg_invalid:
	clr	pin_dsp_busy
	jb	pin_dma_enablel,check_cmd
; 5ah: command group 0

;
; Command group 0: status
;
cmdg_status:
	clr	pin_dsp_busy
cmd_halt:
	; Command 08 is halt (infinite loop).
	jb	command_byte_3,cmd_halt
	; Command 04 is the status command
	jnb	command_byte_2,cmd_not_04
	; Grab the internal status register
	mov	a,status_register
	; Wait for the mailbox to become empty
X04c8:	jb	pin_dav_pc,X04c8
	; Output the status register.
	movx	@r0,a
	; Is DMA recording/playback going on?
	jnb	pin_dma_enablel,continue_dma_op
cmd_not_04:
	ljmp	wait_for_cmd
continue_dma_op:	
	; Reenable timer if we are processing commands during a DMA operation.
	setb	tr0
	ljmp	check_cmd
;
; Command group 4: Setup
;
cmdg_setup_e:
	; Command 48 sets the DMA block transfer size
	jb	command_byte_3,cmd_set_dma_block_size
	; Command 40 sets the time constant
	; Wait for data to become available in the mailbox.
X04da:	jnb	pin_dav_dsp,X04da
	; Get the byte
	movx	a,@r0
	; Set up the timer
	mov	th0,a
	mov	tl0,a
	; Store the time constant value
	mov	time_constant,a
	ljmp	wait_for_cmd
;
cmd_set_dma_block_size:
	; Wait for data byte to become available
	jnb	pin_dav_dsp,cmd_set_dma_block_size
	movx	a,@r0
	; This is the low byte of the DMA block length
	mov	dma_blk_len_lo,a
	; Get the next byte
X04ed:	jnb	pin_dav_dsp,X04ed
	movx	a,@r0
	; This is the high byte of the DMA block length
	mov	dma_blk_len_hi,a
	ljmp	wait_for_cmd

;
; Command group F: Auxiliary commands
;
cmdg_aux_e:
	jb	command_byte_3,cmd_sram_test
	jb	command_byte_2,cmd_checksum
	jb	command_byte_1,cmd_force_interrupt
	jb	command_byte_0,cmd_aux_status
	ljmp	cmd_sine_gen
; Command F2: Forced host PC interrupt
cmd_force_interrupt:
	clr	pin_irequest
	setb	pin_irequest
	ljmp	check_cmd
; Command F8: Test the internal SRAM from 7Fh to 00h.
cmd_sram_test:
	mov	r0,#7fh
	mov	a,#0aah
	; Write and verify AAh to SRAM
sram_test_loop1:
	mov	@r0,a
	cjne	@r0,#0aah,sram_test_end
	djnz	r0,sram_test_loop1
	mov	r0,#7fh
	mov	a,#55h
	; Write and verify 55h to SRAM
sram_test_loop2:
	mov	@r0,a
	cjne	@r0,#55h,sram_test_end
	djnz	r0,sram_test_loop2
sram_test_end:
	; Output indicates which byte failed the test or 0 for success.
	mov	a,r0
	movx	@r0,a
	ljmp	check_cmd
; Command F4: Perform ROM checksum
; r0 and r1 contain 16-bit checksum

; BUG: This routine includes the value of location 1000h in the calculation.
; Some 8051s wrap this back to address 0000h and others use the value at 1000h.
; Since the value at 0000h is 02h, the return value will be the real checksum
; + 02h. The value at 1000h is often FFh (unimplemented or unprogrammed) which
; means the return value will be the real checksum + ffh.
cmd_checksum:
	mov	r0,#0
	mov	r1,#0
	; Start at the end
	mov	dptr,#RESET
csum_loop:
	clr	a
	movc	a,@a+dptr
	; Add current ROM byte to r0
	add	a,r0
	mov	r0,a
	jnc	X0533
	; r0 add overflowed, so add it to r1
	inc	r1
X0533:	
	; Check high byte of data pointer.
	mov	a,dph
	; If it equals 10h, then we are done! Since this check happens at the
	; end, the value at 1000h gets counted in the total (see comment above)
	cjne	a,#10h,csum_not_done
	ljmp	csum_done
csum_not_done:
	; Move to the next ROM byte and continue
	inc	dptr
	sjmp	csum_loop
csum_done:
	; Send MSB of ROM checksum
	mov	a,r1
	movx	@r0,a
	mov	a,r0
	; Wait for the host to empty mailbox
X0541:	jb	pin_dav_pc,X0541
	; Send LSB of ROM checksum
	movx	@r0,a
	ljmp	check_cmd
; Command F1: Get auxiliary DSP status
cmd_aux_status:
	; Outputs port 2 contents to the host PC.
	; On the SB 2.0, the bits are assigned as follows:
	; P2.0: Mute enable (0=speaker enabled)
	; P2.1 to P2.4: Reserved
	; P2.5: Analog comparator bit for recording modes
	; P2.6: Mailbox data available for the PC to read
	; P2.7: Mailbox data available for the 8051 to read
	mov	a,p2
X054a:	jb	pin_dav_pc,X054a
	movx	@r0,a
	ljmp	check_cmd
; Command F0: Generates sine wave
cmd_sine_gen:
	; Set up pointer to sine table
	mov	r0,#40h
	mov	dptr,#sine_table
	; Copy the sine table to SRAM
gen_sine_loop:
	clr	a
	movc	a,@a+dptr
	mov	@r0,a
	inc	dptr
	inc	r0
	cjne	r0,#80h,gen_sine_loop
	; Playback pointer start point of 40h
	mov	r1,#40h
	; This is not used by the sine playback routine
	mov	ram_loops,#0ffh
	; DDS increment of 8
	mov	r7,#8
	; Set up the timer period
	mov	th0,#0c2h
	; Set the timer interrupt vector to the sine handler
	mov	dptr,#vector_sine
	mov	vector_low,dpl
	mov	vector_high,dph
	; Turn on the speaker
	clr	pin_mute_en
	; Enable the timer, and off we go!
	setb	et0
	setb	tr0
	ljmp	check_cmd

;
; Sine wave table to be used for sine wave playback.
; The table contains 64 values of a full sine wave. the midpoint is 7f, the
; maximum is ff, and the minimum is 1.
; Start of the table is at 057Ah, and the last value is at 05B9h
sine_table:
	.db	7fh,73h,67h,5bh,4fh,44h,39h,2fh
	.db	26h,1dh,16h,0fh,0ah,6,3,1
	.db	1,1,3,6,0ah,0fh,16h,1dh
	.db	26h,2fh,39h,44h,4fh,5bh,67h,73h
	.db	80h,8ch,98h,0a4h,0b0h,0bbh,0c6h,0d0h
	.db	0d9h,0e2h,0e9h,0f0h,0f5h,0f9h,0fch,0feh
	.db	0ffh,0feh,0fch,0f9h,0f5h,0f0h,0e9h,0e2h
	.db	0d9h,0d0h,0c6h,0bbh,0b0h,0a4h,98h,8ch

;
; Command group 3: MIDI commands
;
do_midi_cmd:
	jb	command_byte_3,cmd_midi_write_poll
	jnb	command_byte_2,cmd_midi_read_write_poll
	; Command 30: MIDI read poll.
	; Set up warm boot magic number so we can continue where we left off
	; after receiving a DSP reset command.
	mov	warmboot_magic1,#34h
	mov	warmboot_magic2,#12h
	ljmp	cmd_midi_read_write_poll
; Command 38: MIDI write poll.
cmd_midi_write_poll:
	; Wait for last serial transfer to complete
	jnb	ti,cmd_midi_write_poll
	; Clear transfer interrupt bit
	clr	ti
	; Wait for host PC to send us data
X05ce:	jnb	pin_dav_dsp,X05ce
	movx	a,@r0
	; Data arrived, so start serial transfer
	setb	tr0
	mov	sbuf,a
	ljmp	check_cmd
; Commands 34 to 37: MIDI read/write poll with optional time stamp and
; interrupt.
; Registers:
; r0: Write pointer to SRAM buffer
; r1: Read pointer to SRAM buffer
; r4: Bytes remaining in SRAM buffer
; r5, r6, r7: MIDI time stamp value
cmd_midi_read_write_poll:
	jnb	command_byte_1,skip_midi_timestamp_setup
	; Set up timer for MIDI time stamping
	mov	tmod,#21h
	setb	midi_timestamp
	mov	tl0,#17h
	mov	th0,#0fch
	mov	r5,#0
	mov	r6,#0
	mov	r7,#0
	setb	et0
	setb	tr0
skip_midi_timestamp_setup:
	; Clear the receive data buffer
	mov	a,sbuf
	clr	ri
	; Initialize write pointer
	mov	r0,#40h
	; Initialize read pointer
	mov	r1,#40h
	; Initialize bytes remaining counter
	mov	r4,#40h
	ljmp	midi_check_for_input_data
midi_main_loop:
	jnb	ti,midi_check_for_input_data
	jnb	pin_dav_dsp,midi_check_for_input_data
	movx	a,@r0
	jb	command_byte_2,midi_write_poll
	mov	r0,#40h
	mov	r1,#40h
	mov	r4,#40h
	clr	et0
	clr	tr0
	mov	warmboot_magic1,#0
	mov	warmboot_magic2,#0
	clr	midi_timestamp
	mov	tmod,#22h
	ljmp	check_cmd
;
midi_write_poll:
	clr	ti
	mov	sbuf,a
midi_check_for_input_data:
	; Check to see if there is data in the serial input buffer
	jb	ri,midi_has_input_data
	cjne	r4,#40h,X062c
	sjmp	midi_main_loop
;
X062c:	jnb	pin_dav_pc,midi_flush_buffer_to_host
	sjmp	midi_main_loop
midi_has_input_data:
	; There is data in the serial data buffer.
	; Check to see if we need to add a time stamp.
	jnb	command_byte_1,midi_read_no_timestamp
	; Stop the timer
	clr	tr0
	mov	a,r5
	cjne	r4,#0,midi_write_r5
	sjmp	midi_nowrap_writebuffer
;
midi_write_r5:
	; Append LSB of MIDI time stamp to data buffer.
	mov	@r0,a
	inc	r0
	dec	r4
	cjne	r0,#80h,midi_nowrap_writebuffer
	; Wrap to the start of the buffer at 40h
	mov	r0,#40h
midi_nowrap_writebuffer:
	mov	a,r6
	cjne	r4,#0,midi_write_r6
	sjmp	X0652
midi_write_r6:
	; Append middle byte of MIDI time stamp to data buffer.
	mov	@r0,a
	inc	r0
	dec	r4
	; Wrap if needed
	cjne	r0,#80h,X0652
	mov	r0,#40h
X0652:	mov	a,r7
	cjne	r4,#0,midi_write_r7
	sjmp	X0660
midi_write_r7:
	; Append LSB of MIDI time stamp to data buffer
	mov	@r0,a
	inc	r0
	dec	r4
	cjne	r0,#80h,X0660
	mov	r0,#40h
	; Turn the timer on again
X0660:	setb	tr0
midi_read_no_timestamp:
	; Copy a data byte out of the serial data register
	mov	a,sbuf
	; Store it to the serial buffer if there is space remaining.
	cjne	r4,#0,midi_store_read_data_to_buffer
	; Ran out of space, so just drop the byte.
	sjmp	midi_ready_to_receive_more
midi_store_read_data_to_buffer:
	; Store the received data to the SRAM.
	mov	@r0,a
	inc	r0
	dec	r4
	cjne	r0,#80h,midi_ready_to_receive_more
	mov	r0,#40h
midi_ready_to_receive_more:
	; Clear receive flag, we are ready to receive more data.
	clr	ri
	sjmp	midi_main_loop
; BUG: There's no way to get to this code.
	cjne	r4,#40h,midi_space_in_buffer
	ljmp	midi_nowrap_readbuffer
midi_space_in_buffer:
	mov	@r0,a
	inc	r0
	dec	r4
	cjne	r0,#80h,midi_flush_buffer_to_host
	mov	r0,#40h
; END BUG.
midi_flush_buffer_to_host:
	; Send contents of entire SRAM buffer to host PC.
	mov	a,@r1
	inc	r1
	; More space is available now
	inc	r4
	; When we hit the end, wrap back to the beginning
	cjne	r1,#80h,midi_nowrap_readbuffer
	mov	r1,#40h
midi_nowrap_readbuffer:
	; Place MIDI data byte in mailbox
	movx	@r0,a
	; Optionally, send an interrupt to the host PC.
	jnb	command_byte_0,midi_skip_interrupt
	clr	pin_irequest
	setb	pin_irequest
midi_skip_interrupt:
	; Done, go back to the main loop
	ljmp	midi_main_loop
; Command group 2: Recording commands
cmdg_adc_e:
	jb	command_byte_3,cmd_adc_autoinit_direct
	jb	command_byte_2,cmd_adc_dma
	ljmp	cmd_adc_direct
; Command 28h: Auto-init direct ADC
cmd_adc_autoinit_direct:
	setb	dma_autoinit_on
	mov	len_left_lo,dma_blk_len_lo
	mov	len_left_hi,dma_blk_len_hi
	ljmp	X06ca
; Command 24h: DMA ADC
cmd_adc_dma:
	jb	pin_dma_enablel,X06be
	; DMA operation is already going on
	; Wait for additional byte from host PC.
X06ad:	jnb	pin_dav_dsp,X06ad
	; Read length_low argument
	movx	a,@r0
	mov	length_low,a
	; Read length_high argument
X06b3:	jnb	pin_dav_dsp,X06b3
	movx	a,@r0
	mov	length_high,a
	setb	dma_mode_on
	ljmp	X06ca
	; Set up DMA from scratch
	; Read argument byte: length low
X06be:	jnb	pin_dav_dsp,X06be
	movx	a,@r0
	mov	len_left_lo,a
	; Read argument byte: length high
X06c4:	jnb	pin_dav_dsp,X06c4
	movx	a,@r0
	mov	len_left_hi,a
X06ca:
	; Turn on DMA enable line
	clr	pin_dma_enablel
	; Set up interrupt vector
	mov	dptr,#vector_dma_adc
	mov	vector_low,dpl
	mov	vector_high,dph
	setb	mode_dma_adc
	; Start the sample timer!
	setb	tr0
	setb	et0
	ljmp	check_cmd
; Command 20: Direct ADC. This immediately takes one sample and returns it.
cmd_adc_direct:
	; Start DAC at half code, then run SAR algorithm.
	mov	port_dac_out,#80h
	nop	
	nop	
	jnb	pin_adc_comp,X06e8
	clr	pin_dac_7
X06e8:	setb	pin_dac_6
	nop	
	nop	
	jnb	pin_adc_comp,X06f1
	clr	pin_dac_6
X06f1:	setb	pin_dac_5
	nop	
	jnb	pin_adc_comp,X06f9
	clr	pin_dac_5
X06f9:	setb	pin_dac_4
	nop	
	jnb	pin_adc_comp,X0701
	clr	pin_dac_4
X0701:	setb	pin_dac_3
	nop	
	jnb	pin_adc_comp,X0709
	clr	pin_dac_3
X0709:	setb	pin_dac_2
	nop	
	jnb	pin_adc_comp,X0711
	clr	pin_dac_2
X0711:	setb	pin_dac_1
	nop	
	jnb	pin_adc_comp,X0719
	clr	pin_dac_1
X0719:	setb	pin_dac_0
	nop	
	jnb	pin_adc_comp,X0721
	clr	pin_dac_0
	; DAC port now contains acquired sample
X0721:	mov	a,port_dac_out
	; Make sure mailbox is empty
X0723:	jb	pin_dav_pc,X0723
	; Output sample to the host PC.
	movx	@r0,a
	clr	pin_dsp_busy
	ljmp	check_cmd
; Command group 9: High speed record and playback
cmdg_hs_e:
	setb	high_speed
	jnb	command_byte_3,X0736
; Command 98h: High speed record
	setb	record_mode
	ljmp	X0738
; Command 90h: High speed playback
X0736:	 
	clr	record_mode
X0738:
	; Store DMA block length in temporary registers
	mov	r6,dma_blk_len_lo
	mov	r7,dma_blk_len_hi
	; Set up warm boot magic numbers
	mov	warmboot_magic1,#34h
	mov	warmboot_magic2,#12h
	; Turn on DMA
	clr	pin_dma_enablel
	; Turn on sample timer
	setb	et0
	setb	tr0
	; Wait for timer interrupt to fire
X0748:	jb	et0,X0748
	clr	pin_dsp_busy
	ljmp	check_cmd
; Command group 1: Audio playback
cmdg_dac_e:
	jb	command_byte_3,cmd_dac_autoinit
	jb	command_byte_2,cmd_dac_dma
	ljmp	cmd_dac_direct
; Command 18h: DMA playback with auto init DMA.
cmd_dac_autoinit:
	setb	dma_autoinit_on
	mov	len_left_lo,dma_blk_len_lo
	mov	len_left_hi,dma_blk_len_hi
	ljmp	X078e
; Command 14h: DMA playback
cmd_dac_dma:
	jb	pin_dma_enablel,X077e
	; If DMA is already running, then get updated length value from PC.
	clr	pin_dsp_busy
	; Get length low value from host PC
X0769:	jnb	pin_dav_dsp,X0769
	movx	a,@r0
	mov	length_low,a
	; Get length high value from host PC
X076f:	jnb	pin_dav_dsp,X076f
	movx	a,@r0
	mov	length_high,a
	setb	dma_mode_on
	setb	et0
	setb	tr0
	ljmp	check_cmd
	; DMA is not already running, so set it up from scratch
X077e:	clr	pin_dsp_busy
	; Get length low value
X0780:	jnb	pin_dav_dsp,X0780
	movx	a,@r0
	mov	len_left_lo,a
	; Get length high value
X0786:	jnb	pin_dav_dsp,X0786
	movx	a,@r0
	mov	len_left_hi,a
	setb	pin_dsp_busy
	; Enable DMA
X078e:	clr	pin_dma_enablel
	jb	command_byte_1,cmd_dac_dma_use_adpcm_2
	; Set up standard 8-bit DMA DAC vector
	mov	dptr,#vector_dma_dac_8
	setb	mode_dma_dac
	ljmp	X07c0

; Command 16h: DMA DAC with 2-bit ADPCM.
; Registers:
; r2 = ADPCM output sample
; r3 = Number of packed samples remaining in the current data byte
; r5 = ADPCM accumulator
; r6 = Current data byte being decoded
cmd_dac_dma_use_adpcm_2:
	; Set up 2-bit ADPCM vector
	mov	dptr,#vector_dma_dac_adpcm2
	setb	mode_adpcm2
	; If command 17h, fetch first byte as reference value
	jb	command_byte_0,cmd_dac_dma_use_reference
	; Trigger host PC DMA
	setb	pin_drequest
	clr	pin_drequest
	; Wait for value to arrive
X07a7:	jnb	pin_dav_dsp,X07a7
	; Store it
	movx	a,@r0
	mov	r6,a
	mov	r3,#4
	ljmp	X07c0
cmd_dac_dma_use_reference:
	; Trigger DMA to fetch value from host PC
	setb	pin_drequest
	clr	pin_drequest
	; Wait for it to arrive
X07b5:	jnb	pin_dav_dsp,X07b5
	; Write out value to DAC and store it as reference
	movx	a,@r0
	mov	r2,a
	mov	port_dac_out,a
	; Set ADPCM accumulator to 1
	mov	r5,#1
	; Set remaining sample count to 1
	mov	r3,#1
X07c0:
	; Set up interrupt vector and start the timer
	mov	vector_low,dpl
	mov	vector_high,dph
	clr	pin_dsp_busy
	setb	et0
	setb	tr0
	ljmp	check_cmd
; Command 10h: Direct DAC.
cmd_dac_direct:
	clr	pin_dsp_busy
	; Wait for byte from host PC
X07d1:	jnb	pin_dav_dsp,X07d1
	; Write the byte out to the DAC, and we are done. Simple.
	movx	a,@r0
	mov	port_dac_out,a
	ljmp	check_cmd
; Command group 7. ADPCM DAC output commands.
cmdg_dac2_e:
	jb	command_byte_3,cmd_dac_autoinit_adpcm
	jb	command_byte_2,cmd_dac_adpcm
; Command 78: Auto-init DMA ADPCM
cmd_dac_autoinit_adpcm:
	setb	dma_autoinit_on
	mov	len_left_lo,dma_blk_len_lo
	mov	len_left_hi,dma_blk_len_hi
	ljmp	X0815
; Command 74: Standard DMA ADPCM
cmd_dac_adpcm:
	jb	pin_dma_enablel,X0805
	; DMA is already running, so update block length
	clr	pin_dsp_busy
	; Get low byte from host PC
X07f0:	jnb	pin_dav_dsp,X07f0
	movx	a,@r0
	mov	length_low,a
	; Get high byte
X07f6:	jnb	pin_dav_dsp,X07f6
	movx	a,@r0
	mov	length_high,a
	setb	dma_mode_on
	setb	et0
	setb	tr0
	ljmp	check_cmd
X0805:	
	; DMA is not running, so set up the transfer from scratch
	clr	pin_dsp_busy
	; Get length low byte
X0807:	jnb	pin_dav_dsp,X0807
	movx	a,@r0
	mov	len_left_lo,a
	; Get length high byte
X080d:	jnb	pin_dav_dsp,X080d
	movx	a,@r0
	mov	len_left_hi,a
	setb	pin_dsp_busy
	; Turn on DMA
X0815:	clr	pin_dma_enablel
	; Commands 74, 78: 4-bit ADPCM
	jnb	command_byte_1,cmd_dac_adpcm_use_4bit
	; Commands 76, 7A: 2.6-bit ADPCM
	mov	dptr,#vector_dma_dac_adpcm2_6
	setb	mode_adpcm26
	ljmp	X0827
cmd_dac_adpcm_use_4bit:
	; Set up timer interrupt vector appropriately
	mov	dptr,#vector_dma_dac_adpcm4
	setb	mode_adpcm4
X0827:	
	; Least significant bit of command byte indicates reference mode
	jnb	command_byte_0,dac_no_reference
	; Trigger early DMA request to get reference byte
	setb	pin_drequest
	clr	pin_drequest
	; Wait for it to come in
X082e:	jnb	pin_dav_dsp,X082e
	; Store it to the DAC and to r2
	movx	a,@r0
	mov	r2,a
	mov	port_dac_out,a
	; Initialize ADPCM accumulator to 1.
	mov	r5,#1
	; Set up remaining samples per byte to 1.
	mov	r3,#1
	ljmp	X084f
dac_no_reference:
	; No reference value, so we trigger DMA to get first
	; actual sample data byte
	setb	pin_drequest
	clr	pin_drequest
	; Wait for it to come in
X0840:	jnb	pin_dav_dsp,X0840
	; Store it in current sample byte (r6)
	movx	a,@r0
	mov	r6,a
	; Depending on 2.6-bit or 4-bit mode, we have a differing number of
	; samples to process in the incoming data byte.
	jnb	command_byte_1,dac_no_ref_adpcm4
	mov	r3,#3
	ljmp	X084f
;
dac_no_ref_adpcm4:
	mov	r3,#4
	; Set up interrupt vector, start timer.
X084f:	mov	vector_low,dpl
	mov	vector_high,dph
	clr	pin_dsp_busy
	setb	et0
	setb	tr0
	ljmp	check_cmd

; Command 80: Generate silence
cmdg_silence_e:
	; Turn on DMA enable (probably unnecessary)
	clr	pin_dma_enablel
	; Get length low from host PC
X0860:	jnb	pin_dav_dsp,X0860
	movx	a,@r0
	mov	len_left_lo,a
	; Get length high from host PC
X0866:	jnb	pin_dav_dsp,X0866
	movx	a,@r0
	mov	len_left_hi,a
	; Set up interrupt vector, start timer
	mov	dptr,#vector_dac_silence
	mov	vector_low,dpl
	mov	vector_high,dph
	setb	mode_silence
	setb	et0
	setb	tr0
	ljmp	check_cmd
; Command group 5: SRAM playback
cmdg_ram_playback_e:
	jb	command_byte_3,cmd_ram_load
	jb	command_byte_0,cmd_ram_playback
	ljmp	cmd_stop_ram_playback
; Command 58: Load data into SRAM
cmd_ram_load:
	; Wait for data to come in
	jnb	pin_dav_dsp,cmd_ram_load
	; Fetch the argument: the number of RAM samples times two
	movx	a,@r0
	mov	ram_samples_x2,a
	; Fetch the argument: playback loop count
X088d:	jnb	pin_dav_dsp,X088d
	movx	a,@r0
	mov	ram_pb_count,a
	; Fetch the argument: playback loop count (2)
X0893:	jnb	pin_dav_dsp,X0893
	movx	a,@r0
	mov	ram_pb_count2,a
	; Fetch an unused argument.
X0899:	jnb	pin_dav_dsp,X0899
	movx	a,@r0
	mov	ram_pb_unused,a
	mov	r0,#40h
	; Fetch the samples
X08a1:	jnb	pin_dav_dsp,X08a1
	movx	a,@r0
	mov	@r0,a
	inc	r0
	dec	ram_samples_x2
	djnz	ram_samples_x2,X08a1
	; Done fetching all the samples, so reset the data pointer
	mov	r1,#40h
	; Command 59 fetches the samples and then immediately plays them back.
	jb	command_byte_0,cmd_ram_playback
	ljmp	check_cmd
; Command 51: Plays back samples stored in SRAM.
cmd_ram_playback:
	setb	pin_dsp_busy
	; Makes a copy of the arguments
	mov	ram_loops2,ram_pb_count
	; BUG: This probably should copy ram_loops to another variable.
	mov	ram_loops,ram_loops
	mov	ram_pb_unused2,ram_pb_unused
	mov	ram_smps_left,ram_samples_x2
	; Set up SRAM playback timer interrupt vector, then enable the timer.
	mov	dptr,#vector_cmd_ram_playback
	mov	vector_low,dpl
	mov	vector_high,dph
	setb	et0
	setb	tr0
	ljmp	check_cmd
; Command 50: Stops playback of SRAM samples
cmd_stop_ram_playback:
	; Shut off the timer
	clr	et0
	clr	tr0
	ljmp	check_cmd

; Command group D: Miscellaneous commands
cmdg_misc:
	jb	command_byte_2,cmd_dma_continue
	jb	command_byte_3,cmd_spk_stat
	jb	command_byte_0,cmd_speaker_en_dis
	clr	et0
	clr	tr0
	setb	pin_dma_enablel
	ljmp	cmdg_misc_exit
; Command D4: Continue DMA operation
cmd_dma_continue:
	; Enable DMA
	clr	pin_dma_enablel
	; Turn on timer
	setb	et0
	setb	tr0
	ljmp	cmdg_misc_exit
; Command D8: Speaker status
cmd_spk_stat:
	jb	command_byte_1,cmd_exit_autoinit
	jnb	pin_mute_en,X08fe
	clr	a
	ljmp	X0900
;
X08fe:	mov	a,#0ffh
	; Wait for mailbox to empty out
X0900:	jb	pin_dav_pc,X0900
	; Send speaker status. FFh=enabled, 00h=disabled
	movx	@r0,a
	ljmp	cmdg_misc_exit
; Command DA: Exit auto-init DMA operation
cmd_exit_autoinit:
	; Set the flag for the interrupt handler to check
	setb	autoinit_exit
	ljmp	cmdg_misc_exit
; Command D1: Enable speaker
cmd_speaker_en_dis:
	jb	command_byte_1,X0915
	lcall	cmd_speaker_on
	ljmp	cmdg_misc_exit
; Command D3: Disable speaker
X0915:	lcall	cmd_speaker_off
cmdg_misc_exit:
	clr	pin_dsp_busy
	ret	
;
cmd_speaker_on:
	push	acc
	clr	pin_dsp_busy
	; Set DAC to 0.
	mov	port_dac_out,#0
	; Turn on speaker
	clr	pin_mute_en
	; From 0, ramp up the DAC code to 81h
	mov	a,#0
X0926:	mov	port_dac_out,a
	inc	a
	; Delay loop
	mov	r3,#30h
X092b:	djnz	r3,X092b

	cjne	a,#81h,X0926
	; Speaker is now on
	setb	spkr_on
	pop	acc
	ret	
;
cmd_speaker_off:
	push	acc
	clr	pin_dsp_busy
	; Get current DAC value so we can ramp it down slowly.
	mov	a,port_dac_out
	jz	X0947
X093d:	mov	port_dac_out,a
	dec	a
	; Delay
	mov	r3,#30h
X0942:	djnz	r3,X0942
	; Decrement until we hit zero
	cjne	a,#0,X093d
	; Mute the speaker
X0947:	setb	pin_mute_en
	; Speaker is now muted.
	clr	spkr_on
	pop	acc
	ret	

; Command group E: DSP identification
cmd_ident_e:
	jb	command_byte_3,cmd_read_test_reg
	jb	command_byte_2,cmd_write_test_reg
	jb	command_byte_1,cmd_dsp_dma_id
	jb	command_byte_0,cmd_dsp_version
X095a:	jnb	pin_dav_dsp,X095a
	movx	a,@r0
	cpl	a
X095f:	jb	pin_dav_pc,X095f
	movx	@r0,a
	ljmp	check_cmd

; Command E8: Read test register
cmd_read_test_reg:
	; Read test register (2Ah)
	mov	a,2ah
	; Send to host PC
X0968:	jb	pin_dav_pc,X0968
	movx	@r0,a
	ljmp	check_cmd

; Command E4: Write test register
cmd_write_test_reg:
	; Wait for data to arrive
	jnb	pin_dav_dsp,cmd_write_test_reg
	; Write it out to test register (2Ah)
	movx	a,@r0
	mov	2ah,a
	ljmp	check_cmd

; Command E2: Firmware validation check. Uses challenge/response algorithm.
cmd_dsp_dma_id:
	; Wait for challenge byte to come in
	jnb	pin_dav_dsp,cmd_dsp_dma_id
	movx	a,@r0
	setb	pin_dsp_busy
	; Turn on DMA
	clr	pin_dma_enablel
	; Perform magical incantation on challenge byte using two values that
	; are initialized as follows:
	; dsp_dma_id0 = AAh
	; dsp_dma_id1 = 96h

	; dsp_dma_id0 += dsp_dma_id1 XOR challenge_byte
	xrl	a,dsp_dma_id1
	add	a,dsp_dma_id0
	mov	dsp_dma_id0,a
	; dsp_dma_id1 = dsp_dma_id1 >> 2 (actually a rotate)
	mov	a,dsp_dma_id1
	rr	a
	rr	a
	mov	dsp_dma_id1,a
	; Get current value of dsp_dma_id0 and send it to host PC (response)
	mov	a,dsp_dma_id0
X098e:	jb	pin_dav_pc,X098e
	movx	@r0,a
	; Trigger DMA
	setb	pin_drequest
	clr	pin_drequest
	; Wait for it to be sent
X0996:	jb	pin_dav_pc,X0996
	nop	
	; Disable DMA
	setb	pin_dma_enablel
	clr	pin_dsp_busy
	ljmp	check_cmd
; Command E1: Get DSP version
cmd_dsp_version:
	; Locate dsp version number
	mov	dptr,#dsp_version
	clr	a
	movc	a,@a+dptr
	; Transmit major version number
X09a6:	jb	pin_dav_pc,X09a6
	movx	@r0,a
	mov	a,#1
	movc	a,@a+dptr
	; Transmit minor version number
X09ad:	jb	pin_dav_pc,X09ad
	movx	@r0,a
	ljmp	check_cmd

; **************
; ADPCM routines
; **************

; Register uses:
; r2 = ADPCM output sample
; r3 = Number of packed samples remaining in current data byte
; r5 = ADPCM accumulator
; r6 = Current data byte being decoded

;
; ADPCM 2-bit decode routine
;
adpcm_2_decode:
	; Take current data byte, examine
	; the two MSBs.
	mov	a,r6
	rlc	a
	jc	adpcm_2_decode_negative
; Sign bit is positive, so continue
	rlc	a
	; Store it back to the data byte since we know the two MSBs now.
	mov	r6,a
	mov	a,r5
	jc	X09cc
	; So far the value is 00.
	; delta = r5 / 2
	rrc	a
	mov	r5,a
	jnz	X09c4
	; If r5 = 0, then set it to 1.
	inc	r5
	sjmp	adpcm_2_output
X09c4:	
	; r5 != 0 case
	; Add delta to output sample, then store in output sample.
	add	a,r2
	jnc	X09c9
	; If there is a carry out, then saturate it to FF.
	; BUG: this should be #0ffh.
	mov	a,0ffh
X09c9:	mov	r2,a
	sjmp	adpcm_2_output
X09cc:
	; The value is 01.
	clr	c
	; delta = (r5 / 2) + r5
	rrc	a
	add	a,r5
	; Add delta to output sample
	add	a,r2
	jnc	X09d4
	; If there is a carry out, saturate it to ffh.
	mov	a,#0ffh
X09d4:	
	; Store the result back to the output sample
	mov	r2,a
	cjne	r5,#20h,X09da
	sjmp	adpcm_2_output
X09da:	
	; If the ADPCM accumulator != 20h, then multiply it by two.
	mov	a,r5
	add	a,r5
	mov	r5,a
	sjmp	adpcm_2_output
; Incoming bits are either 10 or 11. (sign bit is negative)
adpcm_2_decode_negative:
	; Get the next bit
	rlc	a
	; Save r6 shifted left by two, lining up the next 2 bits for us.
	mov	r6,a
	; Get the ADPCM accumulator value
	mov	a,r5
	jc	X09f4
; Incoming bits are 10.
	rrc	a
	; delta = r5 / 2
	mov	r5,a
	jnz	X09eb
	; If ADPCM accumulator is 0, set it to 1.
	inc	r5
	sjmp	adpcm_2_output
X09eb:	
	; a = Current output sample - delta
	xch	a,r2
	clr	c
	subb	a,r2
	jnc	X09f1
	; Saturate the result at 0 if a borrow occurred.
	clr	a
X09f1:	
	; Output the resulting sample
	mov	r2,a
	sjmp	adpcm_2_output
; Incoming bits are 11.
X09f4:	clr	c
	rrc	a
	; delta = (r5 / 2) + r5
	add	a,r5
	xch	a,r2
	clr	c
	; a = Current output sample - delta
	subb	a,r2
	jnc	X09fd
	; Saturate the result at 0 if a borrow occurred.
	clr	a
X09fd:	
	; Output the result.
	mov	r2,a
	cjne	r5,#20h,X0a03
	sjmp	adpcm_2_output
;
X0a03:
	; If the ADPCM accumulator != 20h, then multiply it by two.
	mov	a,r5
	add	a,r5
	mov	r5,a
adpcm_2_output:
	mov	port_dac_out,r2
	ret

;
; ADPCM 4-bit decode routine
;
adpcm_4_decode:
	mov	a,r5
	clr	c
	rrc	a
	; 27h <- r5 / 2
	mov	27h,a
	; rb3r1 <- r6 (current data byte)
	mov	a,r6
	mov	rb3r1,a
	; Get the most significant nybble of the incoming data
	swap	a
	; Store it back (we process the other nybble later)
	mov	r6,a
	; Mask off the three least significant bits
	anl	a,#7
	; Store in 28h
	mov	28h,a
	; delta = nybble * ADPCM accumulator + (ADPCM accumulator / 2)
	mov	b,r5
	mul	ab
	add	a,27h
	; And store the result in 29h (delta)
	mov	29h,a
	; Grab original data byte again
	mov	a,rb3r1
	rlc	a
	; Check MSB (the sign bit)
	jc	X0a2d
	; MSB is zero, so value is positive. Add the delta to the
	; current sample output value.
	mov	a,29h
	add	a,r2
	jnc	X0a34
	; Saturate it to FFh if there was a carry.
	mov	a,#0ffh
	ljmp	X0a34
;
X0a2d:
	; Sign bit is negative
	mov	a,r2
	; Subtract the delta from the current sample output value.
	clr	c
	subb	a,29h
	jnc	X0a34
	; Saturate it at 00h if there was a borrow.
	clr	a
X0a34:
	; Set the new sample output value to what we calculated just now
	mov	r2,a
	; Check original 4-bit value to see if it is zero
	mov	a,28h
	jz	X0a48
	; It is not zero, so subtract five
	clr	c
	subb	a,#5
	jc	adpcm_4_output
	; Take ADPCM accumulator, multiply by two.
	mov	a,r5
	rl	a
	cjne	a,#10h,X0a4e
	; If it is 10h, make it 8.
	mov	a,#8
	ljmp	X0a4e
;
X0a48:
	; Value coming in is zero
	; Get old r5/2 value
	mov	a,27h
	; Store it to r5 unless it's zero; in that case, set r5=1.
	jnz	X0a4e
	mov	a,#1
X0a4e:
	; Store ADPCM accumulator
	mov	r5,a
adpcm_4_output:
	mov	port_dac_out,r2
	ret	

;
; ADPCM 2.6-bit decode routine
;
adpcm_2_6_decode:
	; 27h = r5 / 2.
	mov	a,r5
	clr	c
	rrc	a
	mov	27h,a
	; rb3r1 = r6 (Store off incoming data)
	mov	a,r6
	mov	rb3r1,a
	; Grab two bits
	rl	a
	rl	a
	cjne	r3,#1,X0a64
	; Bytes remaining = 1, this is the special case
	; Throw away everything except for the LSB.
	anl	a,#1
	ljmp	X0a65
;
X0a64:	
	; "Normal" case where bytes remaining != 1.
	; Grab the 3rd bit
	rl	a
X0a65:	
	; Store back to current data byte (so we can grab the next one next
	; time around).
	mov	r6,a
	; Mask off so we just have the three bits we want
	anl	a,#3
	; Store in 28h
	mov	28h,a
	; Fetch ADPCM accumulator, multiply it by our 3-bit value
	mov	b,r5
	mul	ab
	; Take LSB of result and add r5 / 2 to it.
	; delta = bits * ADPCM accumulator + (ADPCM accumulator / 2)
	add	a,27h
	; Store the result in 29h (delta)
	mov	29h,a
	; Get the original version of our incoming data byte back 
	mov	a,rb3r1
	rlc	a
	; Check the sign bit
	jc	X0a80
	; Positive, so get our result again and add it to the current output
	; sample
	mov	a,29h
	add	a,r2
	jnc	X0a87
	; Saturate it at FFh if there was a carry.
	mov	a,#0ffh
	ljmp	X0a87
;
X0a80:
	; Sign bit is negative so we subtract it from our current output sample
	mov	a,r2
	clr	c
	subb	a,29h
	jnc	X0a87
	; Saturate it at 00h if there was a borrow.
	clr	a
X0a87:	
	; Store it back to the current output sample
	mov	r2,a
	; Get the three bits again
	mov	a,28h
	jz	X0a9a
	cjne	a,#3,adpcm_2_6_output
	; The three bits were 011, so check our accumulator
	cjne	r5,#10h,X0a95
	; ADPCM accumulator is 10h, so just output the sample
	ljmp	adpcm_2_6_output
;
X0a95:	
	; ADPCM accumulator wasn't 10h, so multiply it by two.
	mov	a,r5
	rl	a
	ljmp	X0aa0
;
X0a9a:	
	; Original 3 bits were 000
	mov	a,27h
	; New reference value (r5) becomes r5 / 2 unless it was 0, in which
	; case it becomes 1.
	jnz	X0aa0
	mov	a,#1
X0aa0:	
	; Store ADPCM accumulator
	mov	r5,a
adpcm_2_6_output:
	mov	port_dac_out,r2
	ret	

;
; Copyright notice
;
	.db	"COPYRIGHT(C) CREATIVE TECHNOLOGY"
	.db	" PTE. LTD. (1991) "

;
; Unused data. Perhaps this was some sort of ADPCM lookup table?
;
	.db	0e9h,0e5h,0fah,0f3h,0f8h,0e3h,0edh,0e2h
	.db	0feh,82h,0e9h,83h,8ah,0e9h,0f8h,0efh
	.db	0ebh,0feh,0e3h,0fch,0efh,8ah,0feh,0efh
	.db	0e9h,0e2h,0e4h,0e5h,0e6h,0e5h,0edh,0f3h
	.db	8ah,0fah,0feh,0efh,84h,8ah,0e6h,0feh
	.db	0eeh,84h,8ah,82h,9bh,93h,92h,93h
	.db	83h

;
; Stored DSP version number
;
dsp_version:
	.db	2,2


;
; Padding
;
	.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
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
	.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
	.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
	.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
	.db 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh


