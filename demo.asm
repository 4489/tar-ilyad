; asmsyntax=asm68k

;------------------------------------------------------------------------------
; description  :  demo
;
; created      :  Thu Feb 09, 2017  04:29:16 AM
; modified     :  Thu Jun 04, 2017  19:20:52 PM
;------------------------------------------------------------------------------

                org     $d000

;------------------------------------------------------------------------------
; demo
;------------------------------------------------------------------------------
demo            movem.l d0-a6, -(a7)

                ; init system
                ;--------------------------------------------------------------
                lea     $dff000,  a6
                move.l  #membase, a0
                move.l  #memsize, d0
                bsr     sys_init

                ; init data
                ;--------------------------------------------------------------
                move.l  #$16283903, d0
                move.l  #$befac17f, d1
                bsr     sys_rand_seed
                bsr     swap_init
                bsr     text_init
                bsr     roto_init
                bsr     swap_update

                ; init hw
                ;--------------------------------------------------------------
                lea     .lev3_int, a0
                lea     cop_start, a1
                bsr     sys_waitvsync
                move.l  a0,     $6c
                move.l  a1,     $80(a6)
                move.w  a1,     $88(a6)
                move.w  #$c010, $9a(a6)         ; copper interrupt
                move.w  #$8380, $96(a6)         ; enable rast, cop

                ; wait for exit
                ;--------------------------------------------------------------
.wait           btst    #6, $bfe001
                bne     .wait

                ; done
                ;--------------------------------------------------------------
                bsr     sys_done

                movem.l (a7)+, d0-a6
                rts

                ; level3 (copper) int
                ;--------------------------------------------------------------
.lev3_int       movem.l d0-a6, -(a7)
                bsr     swap_update
                bsr     text_update
                bsr     roto_update
                movem.l (a7)+, d0-a6
                move.w  #$10, $dff09c
                move.w  #$10, $dff09c
                rte


;------------------------------------------------------------------------------
; init swap chains
;------------------------------------------------------------------------------
swap_init       bsr     sys_membase
                move.l  a0, d0
                move.l  a0, d1
                move.l  a0, d2
                move.l  a0, d3
                move.l  a0, d4
                move.l  a0, d5
                add.l   #text_plane,  d0
                add.l   #text_plane,  d1
                add.l   #roto_cop_x1, d2
                add.l   #roto_cop_x2, d3
                add.l   #roto_cop_y1, d4
                add.l   #roto_cop_y2, d5
                move.l  d0, swap_text_plane + 00
                move.l  d1, swap_text_plane + 04
                move.l  d2, swap_roto_cop_x + 00
                move.l  d3, swap_roto_cop_x + 04
                move.l  d4, swap_roto_cop_y + 00
                move.l  d5, swap_roto_cop_y + 04
                rts

;------------------------------------------------------------------------------
; update swap chains
;------------------------------------------------------------------------------
swap_update     move.l  swap_text_plane + 00, d0
                move.l  swap_text_plane + 04, d1
                move.l  d0, swap_text_plane + 04
                move.l  d1, swap_text_plane + 00
                move.l  swap_roto_cop_x + 00, d1
                move.l  swap_roto_cop_x + 04, d2
                move.l  d1, swap_roto_cop_x + 04
                move.l  d2, swap_roto_cop_x + 00
                move.l  swap_roto_cop_y + 00, d2
                move.l  swap_roto_cop_y + 04, d3
                move.l  d2, swap_roto_cop_y + 04
                move.l  d3, swap_roto_cop_y + 00

                ; update copper (text)   TODO: redundant as now single-buffered
                ;--------------------------------------------------------------
                move.w  d0, cop_text_plane + 06
                swap    d0
                move.w  d0, cop_text_plane + 02
                swap    d0
                add.l   #(((304 * 2) / 8) * 1), d0
                move.w  d0, cop_text_plane + 14
                swap    d0
                move.w  d0, cop_text_plane + 10

                ; update copper (roto)
                ;--------------------------------------------------------------
                move.w  d2, cop_roto_cop_y + 06
                swap    d2
                move.w  d2, cop_roto_cop_y + 02
                rts

swap_text_plane dc.l    0, 0
swap_roto_cop_x dc.l    0, 0
swap_roto_cop_y dc.l    0, 0


;------------------------------------------------------------------------------
; init copper rotozoom
;------------------------------------------------------------------------------
roto_init       bsr     sys_membase
                move.l  a0, a1
                move.l  a0, a2
                move.l  a0, a3
                add.l   #roto_cop_y1, a0
                add.l   #roto_cop_y2, a1
                add.l   #roto_cop_x1, a2
                add.l   #roto_cop_x2, a3

                ; vars
                ;--------------------------------------------------------------
                move.l  #$1b000000, d0                      ; y-pos start
                move.l  #$002bfffe, d3                      ; h-pos wait
                move.l  #((284 - (12 * 9)) / 2) << 24, d4
                move.l  #((284 + (12 * 9)) / 2) << 24, d5
                add.l   d0, d4                              ; y-pos text on
                add.l   d0, d5                              ; y-poa text off

                ; start lists
                ;--------------------------------------------------------------
                move.l  a0, d1
                swap    d1
                move.w  #$0080, (a0)+           ; cop1 and cop2 hi-words (once)
                move.w  #$0080, (a1)+
                move.w  d1,     (a0)+
                move.w  d1,     (a1)+
                move.w  #$0084, (a0)+
                move.w  #$0084, (a1)+
                move.w  d1,     (a0)+
                move.w  d1,     (a1)+

                ; y batches
                ;--------------------------------------------------------------
                move.l  #(284 / 4) - 1, d7
.y1             move.w  #$0086, (a0)+           ; cop2 lo-word (cols)
                move.w  #$0086, (a1)+
                move.w  a2,     (a0)+
                move.w  a3,     (a1)+

                ; x cols (cop2)
                ;--------------------------------------------------------------
                move.l  #(352 / 8) - 1, d1
.x1             move.l  #$01800000, (a2)+
                move.l  #$01800000, (a3)+
                dbf     d1, .x1
                move.l  #$01800000, (a2)+
                move.l  #$01800000, (a3)+
                move.l  #$00880000, (a2)+       ; cop1 jmp (ret)
                move.l  #$00880000, (a3)+

                ; y batch
                ;--------------------------------------------------------------
                move.l  #4 - 1, d6
.y2             cmp.l   d4, d0
                bne     .nottexton
                move.l  #$0100a200, (a0)+
                move.l  #$0100a200, (a1)+
.nottexton      cmp.l   d5, d0
                bne     .nottextoff
                move.l  #$01000200, (a0)+
                move.l  #$01000200, (a1)+
.nottextoff     move.l  d0, d1
                or.l    d3, d1                  ; wait
                move.l  d1, (a0)+
                move.l  d1, (a1)+
                move.l  a0, d1
                move.l  a1, d2
                add.l   #8, d1
                add.l   #8, d2
                move.w  #$0082,     (a0)+       ; cop1 lo-word (ret addr)
                move.w  #$0082,     (a1)+
                move.w  d1,         (a0)+
                move.w  d2,         (a1)+
                move.l  #$008a0000, (a0)+       ; cop2 jmp (cols)
                move.l  #$008a0000, (a1)+
                add.l   #$01000000, d0
                dbf     d6, .y2
                dbf     d7, .y1

                ; end lists
                ;--------------------------------------------------------------
                move.l  #cop_start, d1
                move.w  #$0082,     (a0)+
                move.w  #$0082,     (a1)+
                move.w  d1,         (a0)+
                move.w  d1,         (a1)+
                move.w  #$0080,     (a0)+
                move.w  #$0080,     (a1)+
                swap    d1
                move.w  d1,         (a0)+
                move.w  d1,         (a1)+
                move.l  #$009c8010, (a0)+
                move.l  #$009c8010, (a1)+
                move.l  #$fffffffe, (a0)+
                move.l  #$fffffffe, (a1)+

                ; build texture (with guardband)
                ;--------------------------------------------------------------
                bsr     sys_membase
                add.l   #roto_texture, a0
                lea     tile_data + 8, a1
                lea     tile_palette,  a2
                lea     .guardband,    a3
                move.l  #(96 + 192 + 96) - 1, d7
.tex_y          move.l  (a3)+, d1
                mulu    #192,  d1
                lea     .guardband, a4
                move.l  #(96 + 192 + 96) - 1, d6
.tex_x          move.l  (a4)+, d0
                add.l   d1, d0
                move.l  #0, d2
                move.b  (a1, d0.l), d2
                add.w   d2, d2
                move.w  (a2, d2.w), (a0)+
                dbf     d6, .tex_x
                dbf     d7, .tex_y
                rts

                ; TODO: remove - stop being lazy and do the math
                ;--------------------------------------------------------------
.guardband      rept    96
                dc.l    REPTN + (192 - 96)
                endr
                rept    192
                dc.l    REPTN
                endr
                rept    96
                dc.l    REPTN
                endr

;------------------------------------------------------------------------------
; update copper rotozoom
;------------------------------------------------------------------------------
roto_update     move.l  a6, -(a7)

                bsr     sys_membase
                add.l   #roto_texture + (((384 * 192) + 192) * 2), a0      ; center of texture
                lea     sin_table + (256 * 0), a1
                lea     sin_table + (256 * 2), a2

                ; update translation, rotation, and zoom params
                ;--------------------------------------------------------------
                lea     .tran, a3
                bsr     .param_update
                move.l  d0, d4
                lea     .roto, a3
                bsr     .param_update
                move.l  d0, d5
                lea     .zoom, a3
                bsr     .param_update
                move.l  d0, d6

                ; bring translation, rotation, and zoom params into range
                ;--------------------------------------------------------------
                asr.l   #5, d4
                asr.l   #5, d5
                asr.l   #4, d6
                divs    #192, d4
                swap    d4
                ext.l   d4
                and.w   #$7fe, d5
                add.w   #$800, d6

                ; transform UV vectors
                ;--------------------------------------------------------------
                move.w  (a2, d5.w), d0
                move.w  (a1, d5.w), d1
                muls    d6, d0
                muls    d6, d1
                asr.l   #8, d0
                asr.l   #8, d1
                move.l  d1, d2
                move.l  d0, d3
                asr.l   #1, d2                      ; because double height (8*4)
                asr.l   #1, d3                      ; because double height (8*4)
                neg.l   d2
                move.l  d0, .Ux                     ; +cos(a) * zoom
                move.l  d1, .Uy                     ; +sin(a) * zoom
                move.l  d2, .Vx                     ; -sin(a) * zoom
                move.l  d3, .Vy                     ; +cos(a) * zoom

                ; consts
                ;--------------------------------------------------------------
                move.l  #7,     d6                  ; mul math
                move.l  #$8000, d7                  ; texel center

                ; translate from center                  texture size 384x384x2
                ;--------------------------------------------------------------
                asr.l   #4, d0
                asr.l   #4, d1
                asr.l   #4, d2
                asr.l   #4, d3
                muls    #(((352 * 16) / 8) / 2), d0
                muls    #(((352 * 16) / 8) / 2), d1
                muls    #(((284 * 16) / 4) / 2), d2
                muls    #(((284 * 16) / 4) / 2), d3
                swap    d0
                swap    d1
                swap    d2
                swap    d3
                ext.l   d0
                ext.l   d1
                ext.l   d2
                ext.l   d3
                add.l   d2, d0
                add.l   d3, d1
                add.l   d4, d0
                asl.l   d6, d1
                add.l   d1, d0
                add.l   d1, d1
                add.l   d1, d0
                add.l   d0, d0
                sub.l   d0, a0

                ; calc dV table                          texture size 384x384x2
                ;--------------------------------------------------------------
                lea     .dV_table, a1
                move.l  d7,  d0
                move.l  d7,  d1
                move.l  .Vx, d2
                move.l  .Vy, d3
                rept    (284 / 4)
                move.l  d0, d4
                move.l  d1, d5
                add.l   d2, d0
                add.l   d3, d1
                swap    d4
                swap    d5
                ext.l   d4
                ext.l   d5
                asl.l   d6, d5
                add.l   d5, d4
                add.l   d5, d5
                add.l   d5, d4
                add.l   d4, d4
                add.l   a0, d4
                move.l  d4, (a1)+
                endr

                ; calc dU table                          texture size 384x384x2
                ;--------------------------------------------------------------
                lea     .dU_table, a1
                move.l  d7,  d0
                move.l  d7,  d1
                move.l  .Ux, d2
                move.l  .Uy, d3
                move.l  #0,  d4
                rept    ((352 / 8) - 1)
                move.l  d4, d7
                add.l   d2, d0
                add.l   d3, d1
                move.l  d0, d4
                move.l  d1, d5
                swap    d4
                swap    d5
                ext.l   d4
                ext.l   d5
                asl.l   d6, d5
                add.l   d5, d4
                add.l   d5, d5
                add.l   d5, d4
                add.l   d4, d4
                move.l  d4, d5
                sub.l   d7, d5
                move.w  d5, (a1)+
                endr

                ; texture -> copper                  display size 352x284 / 8x4
                ;--------------------------------------------------------------
                move.l  swap_roto_cop_x, a6

                movem.w .dU_table + (0 * 2), d0-a3
                lea     .dV_table, a4
                rept    (284 / 4)
                move.l  (a4), a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) +  (0 * 4)) + 2)(a6)
                add.w   d0, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) +  (1 * 4)) + 2)(a6)
                add.w   d1, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) +  (2 * 4)) + 2)(a6)
                add.w   d2, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) +  (3 * 4)) + 2)(a6)
                add.w   d3, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) +  (4 * 4)) + 2)(a6)
                add.w   d4, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) +  (5 * 4)) + 2)(a6)
                add.w   d5, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) +  (6 * 4)) + 2)(a6)
                add.w   d6, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) +  (7 * 4)) + 2)(a6)
                add.w   d7, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) +  (8 * 4)) + 2)(a6)
                add.w   a0, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) +  (9 * 4)) + 2)(a6)
                add.w   a1, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (10 * 4)) + 2)(a6)
                add.w   a2, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (11 * 4)) + 2)(a6)
                add.w   a3, a5
                move.l  a5, (a4)+
                endr

                movem.w .dU_table + (12 * 2), d0-a3
                lea     .dV_table, a4
                rept    (284 / 4)
                move.l  (a4), a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (12 * 4)) + 2)(a6)
                add.w   d0, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (13 * 4)) + 2)(a6)
                add.w   d1, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (14 * 4)) + 2)(a6)
                add.w   d2, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (15 * 4)) + 2)(a6)
                add.w   d3, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (16 * 4)) + 2)(a6)
                add.w   d4, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (17 * 4)) + 2)(a6)
                add.w   d5, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (18 * 4)) + 2)(a6)
                add.w   d6, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (19 * 4)) + 2)(a6)
                add.w   d7, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (20 * 4)) + 2)(a6)
                add.w   a0, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (21 * 4)) + 2)(a6)
                add.w   a1, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (22 * 4)) + 2)(a6)
                add.w   a2, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (23 * 4)) + 2)(a6)
                add.w   a3, a5
                move.l  a5, (a4)+
                endr

                movem.w .dU_table + (24 * 2), d0-a3
                lea     .dV_table, a4
                rept    (284 / 4)
                move.l  (a4), a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (24 * 4)) + 2)(a6)
                add.w   d0, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (25 * 4)) + 2)(a6)
                add.w   d1, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (26 * 4)) + 2)(a6)
                add.w   d2, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (27 * 4)) + 2)(a6)
                add.w   d3, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (28 * 4)) + 2)(a6)
                add.w   d4, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (29 * 4)) + 2)(a6)
                add.w   d5, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (30 * 4)) + 2)(a6)
                add.w   d6, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (31 * 4)) + 2)(a6)
                add.w   d7, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (32 * 4)) + 2)(a6)
                add.w   a0, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (33 * 4)) + 2)(a6)
                add.w   a1, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (34 * 4)) + 2)(a6)
                add.w   a2, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (35 * 4)) + 2)(a6)
                add.w   a3, a5
                move.l  a5, (a4)+
                endr

                movem.w .dU_table + (36 * 2), d0-d6
                lea     .dV_table, a4
                rept    (284 / 4)
                move.l  (a4)+, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (36 * 4)) + 2)(a6)
                add.w   d0, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (37 * 4)) + 2)(a6)
                add.w   d1, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (38 * 4)) + 2)(a6)
                add.w   d2, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (39 * 4)) + 2)(a6)
                add.w   d3, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (40 * 4)) + 2)(a6)
                add.w   d4, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (41 * 4)) + 2)(a6)
                add.w   d5, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (42 * 4)) + 2)(a6)
                add.w   d6, a5
                move.w  (a5), (((REPTN * (((352 / 8) * 4) + 4 + 4)) + (43 * 4)) + 2)(a6)
                endr

                move.l  (a7)+, a6
                rts

.param_update   movem.w (a3), d0-d2/a4-a6
                add.w   a4, d0
                add.w   a5, d1
                add.w   a6, d2
                and.w   #$7fe, d0
                and.w   #$7fe, d1
                and.w   #$7fe, d2
                move.w  d0, (a3)+
                move.w  d1, (a3)+
                move.w  d2, (a3)
                move.w  (a1, d0.w), d0
                move.w  (a1, d1.w), d1
                move.w  (a1, d2.w), d2
                ext.l   d0
                ext.l   d1
                ext.l   d2
                add.l   d1, d0
                add.l   d2, d0
                add.l   #2, d0
                asr.l   #2, d0
                rts

.roto           dc.w    0, 0, 0, 11, 6, 1
.zoom           dc.w    0, 0, 0,  4, 3, 1
.tran           dc.w    0, 0, 0,  5, 4, 1

.Ux             dc.l    0
.Uy             dc.l    0
.Vx             dc.l    0
.Vy             dc.l    0

.dU_table       ds.w    (352 / 8)
.dV_table       ds.l    (284 / 4)


;------------------------------------------------------------------------------
; init text print
;------------------------------------------------------------------------------
text_init       bsr     sys_membase
                move.l  a0, a1
                add.l   #text_ord_tab, a0
                add.l   #text_pre_tab, a1
                move.l  #text_0, _text_cur
                move.l  #text_1, _text_nxt
                move.l  a0, _text_ord
                move.l  a1, _text_pre
                move.l  a1, _text_pre_end
                move.l  #0, _text_tick

                ; build order table
                ;--------------------------------------------------------------
                move.l  _text_ord, a0
                move.l  #(76 * 12) - 1, d7
.build          move.l  d7,  d2
                move.l  d7,  d0
                divu    #76, d0
                move.l  d0,  d1
                mulu    #76 * 9, d1
                swap    d0
                add.w   d1, d0
                lsl.w   #2, d2
                move.w  d7, 00(a0, d2.w)
                move.w  d0, 02(a0, d2.w)
                dbf     d7, .build

                ; shuffle order table
                ;--------------------------------------------------------------
                move.l  _text_ord, a0
                move.l  #(76 * 12) - 1, d7
.shuffle        bsr     sys_rand
                and.l   #$ffff, d0
                move.w  d7, d1
                divu    d7, d0
                swap    d0
                lsl.w   #2, d0
                lsl.w   #2, d1
                move.l  (a0, d0.w), d2
                move.l  (a0, d1.w), d3
                move.l  d2, (a0, d1.w)
                move.l  d3, (a0, d0.w)
                sub.w   #1, d7
                bne     .shuffle
                rts

;------------------------------------------------------------------------------
; update text print
;------------------------------------------------------------------------------
text_update     move.l  _text_tick, d0
                cmp.l   #((76 * 12) / 16) + ((((76 * 12) / 16) * 8) * 2), d0
                bge     .nextpage
                cmp.l   #((76 * 12) / 16) + ((((76 * 12) / 16) * 8) * 1), d0
                bge     .done
                cmp.l   #((76 * 12) / 16) + ((((76 * 12) / 16) * 8) * 0), d0
                bge     .update

.prepare        ; prepare one batch (16 chars) per frame during idle time
                ;--------------------------------------------------------------
                move.l  _text_ord,     a0
                move.l  _text_pre_end, a1
                move.l  _text_cur,     a2
                move.l  _text_nxt,     a3
                lsl.w   #6, d0                  ; 4 (batches of 16) + 2 (4 byte struct)
                add.w   d0, a0
                move.w  #$ff, d4
                move.w  #$20, d5
                move.w  #$03, d6
                REPT    16
                inline
                movem.w (a0)+, d0-d1
                move.b  (a2, d0.w), d2
                move.b  (a3, d0.w), d3
                cmp.b   d2, d3
                beq     .same
                and.w   d4, d2
                and.w   d4, d3
                sub.w   d5, d2
                sub.w   d5, d3
                lsl.w   d6, d2
                lsl.w   d6, d3
                move.w  d0, (a1)+
                move.w  d1, (a1)+
                move.w  d2, (a1)+
                move.w  d3, (a1)+
.same           einline
                ENDR
                move.l  a1, _text_pre_end
                add.l   #1, _text_tick
                rts

.update         ; update one batch (16 chars) per frame during update time
                ;--------------------------------------------------------------
                move.l  swap_text_plane, a0
                move.l  _text_pre,       a1
                move.l  _text_pre_end,   a2
                lea     text_charset,    a3
                lea     text_charmask,   a4
                sub.w   #((76 * 12) / 16), d0
                move.w  d0, d1
                lsr.w   #3, d0
                lsl.w   #7, d0              ; 4 (batches of 16) + 3 (8 byte struct)
                and.w   #7, d1
                lsl.w   #3, d1
                add.w   d0, a1
                add.w   d1, a4
                move.l  (a4)+, d4
                move.l  (a4)+, d5
                move.l  d4, d6
                move.l  d5, d7
                not.l   d6
                not.l   d7
                REPT    16
                cmp.l   a2, a1
                bge     .done
                movem.w (a1)+, d0-d3
                lea     (a0, d1.w),   a4
                move.l  00(a3, d2.w), d0
                move.l  04(a3, d2.w), d1
                move.l  00(a3, d3.w), d2
                move.l  04(a3, d3.w), d3
                and.l   d4, d0
                and.l   d5, d1
                and.l   d6, d2
                and.l   d7, d3
                or.l    d2, d0
                or.l    d3, d1
                move.b  d0, ((76 * 3) + 76)(a4)
                move.b  d1, ((76 * 7) + 76)(a4)
                swap    d0
                swap    d1
                move.b  d0, ((76 * 1) + 76)(a4)
                move.b  d1, ((76 * 5) + 76)(a4)
                lsr.l   #8, d0
                lsr.l   #8, d1
                move.b  d0, ((76 * 0) + 76)(a4)
                move.b  d1, ((76 * 4) + 76)(a4)
                swap    d0
                swap    d1
                move.b  d0, ((76 * 2) + 76)(a4)
                move.b  d1, ((76 * 6) + 76)(a4)
                ENDR
.done           add.l   #1, _text_tick
                rts

.nextpage       move.l  _text_nxt,  _text_cur
                add.l   #(76 * 12), _text_nxt
                cmp.l   #text_end,  _text_nxt
                bne     .nowrap
                move.l  #text_1,    _text_nxt
.nowrap         move.l  _text_pre,  _text_pre_end
                move.l  #0,         _text_tick
                rts

_text_cur       dc.l    0
_text_nxt       dc.l    0
_text_ord       dc.l    0
_text_pre       dc.l    0
_text_pre_end   dc.l    0
_text_tick      dc.l    0


;------------------------------------------------------------------------------
; system                                  not os-friendly as os is dead already
;------------------------------------------------------------------------------
sys_init        move.l  a0, _sys_membase
                move.l  d0, _sys_memsize
                bsr     _sys_kill
                rts

sys_done        bsr     _sys_kill
                clr.l   _sys_membase
                clr.l   _sys_memsize
                rts

_sys_kill       bsr     sys_waitvsync
                move.w  #$7fff, d0
                move.w  d0,  $9a(a6)
                move.w  d0,  $96(a6)
                move.w  d0,  $9c(a6)
                move.w  d0,  $9c(a6)
                move.w  #0, $180(a6)
                bsr     sys_waitblit
                bsr     sys_waitvsync
                bsr     sys_waitvsync
                move.l  _sys_membase, a0
                move.l  _sys_memsize, d0
                beq     .done
                move.l  a0, a1
                add.l   d0, a1
                move.l  #0, d0
.clear          move.l  d0, (a0)+
                move.l  d0, (a0)+
                move.l  d0, (a0)+
                move.l  d0, (a0)+
                cmp.l   a0, a1
                bne     .clear
.done           rts

sys_waitblit    btst.b  #6, $02(a6)
.wait           btst.b  #6, $02(a6)
                bne     .wait
                rts

sys_waitvsync   move.l  $04(a6), d0
                and.l   #$1ff00, d0
                cmp.l   #$12f00, d0
                bne     sys_waitvsync
.wait           move.l  $04(a6), d0
                and.l   #$1ff00, d0
                cmp.l   #$12f00, d0
                beq     .wait
                rts

sys_membase     move.l  _sys_membase, a0
                rts

sys_rand_seed   move.l  d0, _sys_rand_state + 00
                move.l  d1, _sys_rand_state + 04
                rts

sys_rand        move.l  _sys_rand_state + 00, d2
                move.l  _sys_rand_state + 04, d1
                move.l  d2, d0
                lsl.l   #2, d2
                eor.l   d0, d2
                move.l  d1, d0
                lsr.l   #3, d0
                eor.l   d1, d0
                eor.l   d2, d0
                lsr.l   #7, d2
                eor.l   d2, d0
                move.l  d1, _sys_rand_state + 00
                move.l  d0, _sys_rand_state + 04
                rts

_sys_membase    dc.l    0
_sys_memsize    dc.l    0
_sys_rand_state dc.l    0, 0


;------------------------------------------------------------------------------
; .data
;------------------------------------------------------------------------------

                ; copperlist
                ;--------------------------------------------------------------
                cnop    0, 16
cop_start       dc.l    $01fc0000
                dc.l    $008e1b81           ; overscan
                dc.l    $009037c1           ; overscan
                dc.l    $00920040           ; hires
                dc.l    $009480d0           ; hires
                dc.l    $01000200
                dc.l    $01020001           ; offset text shadow
                dc.l    $01040000
                dc.l    $01060c00
                dc.l    $01080000
                dc.l    $010a0000
                dc.l    $010c0011
                dc.l    $01820000           ; col0
                dc.l    $01820777           ; col1
                dc.l    $01840eee           ; col2
                dc.l    $01860eee           ; col3
cop_text_plane  dc.l    $00e00000           ; bpl1_h
                dc.l    $00e20000           ; bplh_l
                dc.l    $00e40000           ; bpl2_h
                dc.l    $00e60000           ; bpl2_l
cop_roto_cop_y  dc.l    $00800000           ; cop1_h
                dc.l    $00820000           ; cop1_l
                dc.l    $00880000           ; cop1_jmp

                ; text charset
                ;--------------------------------------------------------------
                cnop    0, 4
text_charset    dc.l    $00000000,$00000000,$18181818,$18001800,$6c6c2400,$00000000,$6c6cfe6c,$fe6c6c00
                dc.l    $107cd07c,$16167c10,$60967c18,$306cd20c,$70d870f6,$dcd87c06,$30301020,$00000000
                dc.l    $18306060,$60301800,$30180c0c,$0c183000,$006c38fe,$386c0000,$0018187e,$18180000
                dc.l    $00000000,$30301020,$0000007c,$00000000,$00000000,$00303000,$00060c18,$3060c000
                dc.l    $0078ccde,$f6e67c00,$18183818,$18187e00,$7c063c60,$c0c0fe00,$3c061c06,$46c67c00
                dc.l    $1818306c,$ccfe0c00,$f8c0fc06,$46cc7800,$70c0fcc6,$c6cc7800,$fe060c18,$18181800
                dc.l    $78cc7cc6,$c6cc7800,$78ccc6c6,$7e061c00,$00003030,$00303000,$00003030,$00301020
                dc.l    $00183060,$30180000,$00007c00,$007c0000,$0030180c,$18300000,$7cc6063c,$30003000
                dc.l    $00000000,$00000000,$78ccc6fe,$c6c6c600,$f8ccfcc6,$c6ccf800,$78ccc0c0,$c0c67c00
                dc.l    $f8ccc6c6,$c6c6fc00,$fec0fcc0,$c0c0fe00,$fec0fcc0,$c0c0c000,$3860c0ce,$c6c67e06
                dc.l    $c6c6c6fe,$c6c6c600,$7e181818,$18187e00,$0e060606,$c6c67c00,$c6ccd8f0,$d8ccc600
                dc.l    $c0c0c0c0,$c0c0fe00,$c6eefed6,$c6c6c600,$c6e6f6de,$cec6c600,$78ccc6c6,$c6c67c00
                dc.l    $f8ccc6c6,$fcc0c000,$78ccc6c6,$c6d67c0c,$f8ccc6c6,$fcd8cc06,$78c07c06,$46c67c00
                dc.l    $7e181818,$18181800,$c6c6c6c6,$c6c67c00,$c6c6c66c,$6c383800,$c6c6c6d6,$feeec600
                dc.l    $c66c3838,$6cc6c600,$c6c6c67c,$0c0c0c00,$fe0c1830,$60c0fe00,$38303030,$30303800
                dc.l    $00c06030,$180c0600,$38181818,$18183800,$10386c00,$00000000,$00000000,$000000fe
                dc.l    $30302010,$00000000,$003c067e,$c6c67e00,$c0f8ccc6,$c6c6fc00,$0078ccc0,$c0c67c00
                dc.l    $063e66c6,$c6c67e00,$0078ccfc,$c0c67c00,$386c6078,$60606060,$007ec6c6,$c67e067c
                dc.l    $c0f8ccc6,$c6c6c600,$18003818,$18187e00,$0c001c0c,$0c0c4c38,$c0ccd8f0,$d8ccc600
                dc.l    $38181818,$18187e00,$00c4eefe,$d6c6c600,$00f8ccc6,$c6c6c600,$0078ccc6,$c6c67c00
                dc.l    $00f8ccc6,$c6c6fcc0,$003e66c6,$c6c67e06,$00fcc6c0,$c0c0c000,$0078c07c,$06c67c00
                dc.l    $307c3030,$30321c00,$00c6c6c6,$c6c67e00,$00c6c66c,$6c383800,$00c6d6fe,$7c6c4400
                dc.l    $00c66c38,$386cc600,$00c6c6c6,$c67e067c,$00fe0c18,$3060fe00,$003366cc,$66330000
                dc.l    $3870e0c1,$83070e1c,$00cc6633,$66cc0000,$729c0000,$00000000,$3870e0c1,$83070e1c

                ; text charmask (8 frames)
                ;--------------------------------------------------------------
                cnop    0, 4
text_charmask   dc.b    %11111111,%11111111,%11111111,%11111111,%11111111,%11111111,%11111111,%11111111
                dc.b    %11111011,%10111111,%11111110,%11111011,%10111111,%11111101,%11110111,%11110111
                dc.b    %11101011,%10111101,%01111010,%11101011,%10111011,%11011101,%11110110,%01110111
                dc.b    %10101011,%10110101,%01011010,%10101011,%10101010,%10010101,%01110110,%01110101
                dc.b    %10100010,%10010100,%01010010,%10101000,%10100010,%00010101,%00110100,%01010100
                dc.b    %00100010,%10000100,%00010010,%10001000,%00100010,%00010100,%00100100,%01000100
                dc.b    %00100000,%10000000,%00010000,%10000000,%00100000,%00010000,%00100000,%01000000
                dc.b    %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000

                ; text pages
                ;--------------------------------------------------------------
                cnop    0, 4
text_0          dc.b    "                                                                            "
                dc.b    "                                                                            "
                dc.b    "                                                                            "
                dc.b    "                                                                            "
                dc.b    "                                                                            "
                dc.b    "                                                                            "
                dc.b    "                                                                            "
                dc.b    "                                                                            "
                dc.b    "                                                                            "
                dc.b    "                                                                            "
                dc.b    "                                                                            "
                dc.b    "                                                                            "
text_1          dc.b    "[   1   ]  Infinite Lives  [on/off]     [   a   ]  Select Weapon :: ASTAR   "
                dc.b    "[   2   ]  Invulnerability [on/off]     [   b   ]  Select Weapon :: BUSTAR  "
                dc.b    "[   3   ]  Ignore PowerUps [on/off]     [   c   ]  Select Weapon :: CORTYX  "
                dc.b    "[   4   ]  Radid Fire      [on/off]     [   d   ]  Select Weapon :: DOOLYX  "
                dc.b    "[   5   ]  Enemy Bullets   [on/off]     [   e   ]  Select Weapon :: ESTARIL "
                dc.b    "[   ]   ]  Ship Speed++                 [   f   ]  Select Weapon :: FERYL   "
                dc.b    "[   [   ]  Ship Speed--                 [   g   ]  Select Weapon :: GANTEUS "
                dc.b    "[ ENTER ]  Level Complete               [   h   ]  Select Weapon :: HUN     "
                dc.b    "[ SPACE ]  Add Life                     [   i   ]  Select Weapon :: ITAX    "
                dc.b    "                                        [   j   ]  Select Weapon :: JASTORYX"
                dc.b    "                                        [   k   ]  Select Weapon :: KYUS    "
                dc.b    "The Adane Remasters  [ 1/3 ]  Ilyad     [   l   ]  Select Weapon :: LEITUN  "
text_2          dc.b    "[ CRACK ]  Custom protection (P.Adane)  [  ADD  ]  6 x 21 in-game keys      "
                dc.b    "           - TVD/SMC/DMA obsf                      Bundled loads            "
                dc.b    "           - MFM longtracks                        Highscore save to floppy "
                dc.b    "           - Checksums (tamper/debug)              Loaders replaced         "
                dc.b    "                                                   Data repacked            "
                dc.b    "                                                   Intro skip               "
                dc.b    "[  FIX  ]  Self-modifying code                                              "
                dc.b    "           Keyboard handlers                                                "
                dc.b    "           Screen transitions           [ CHECK ]  Verified A500, A500+     "
                dc.b    "           Audio issues                            Verified A600            "
                dc.b    "           Copper issues                           Verified A1200           "
                dc.b    "           Blitter issues                          Verified A4000           "
text_end        equ     *

                ; sin table
                ;--------------------------------------------------------------
                cnop    0, 4
sin_table       incbin  'sin.bin'
                incbin  'sin.bin'

                ; source tile (192x192)
                ;--------------------------------------------------------------
                cnop    0, 4
tile_palette    include 'tile.pal'
                cnop    0, 4
tile_data       incbin  'tile.tif'


;------------------------------------------------------------------------------
; memory maps
;------------------------------------------------------------------------------
demoend         equ     *
                cnop    0, 65536
membase         equ     *

MEMSTART        macro
memoffset       set     0
                endm

MEMADD          macro
\1              set     memoffset
memoffset       set     memoffset + (((\2) + 15) & ~15)
                endm

                ; chip map
                ;--------------------------------------------------------------
                MEMSTART
                MEMADD  roto_cop_x1,  ((284 / 4) * (((352 / 8) * 4) + 4 + 4))
                MEMADD  roto_cop_x2,  ((284 / 4) * (((352 / 8) * 4) + 4 + 4))
                MEMADD  roto_cop_y1,  (4 + 4) + ((284 / 4) * (4 + (4 * ((3 * 4))))) + 4 + 4 + (4 * 4)
                MEMADD  roto_cop_y2,  (4 + 4) + ((284 / 4) * (4 + (4 * ((3 * 4))))) + 4 + 4 + (4 * 4)
                MEMADD  text_plane,   ((128 * (((304 * 2) / 8)))) + ((304 * 2) / 8)
                MEMADD  text_ord_tab, ((76 * 12) * (2 * 2))
                MEMADD  text_pre_tab, ((76 * 12) * (4 * 2))
                MEMADD  roto_texture, (((96 + 192 + 96) * (96 + 192 + 96)) * 2)
                MEMADD  memsize, 0


;------------------------------------------------------------------------------
; debug info
;------------------------------------------------------------------------------

                printv  demo
                printv  demoend
                printv  membase
                printv  memsize
                printv  membase + memsize
