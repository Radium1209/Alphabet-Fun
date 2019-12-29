datas segment
	; 字母的初始位置
	letter_pos db 10,3,12,4,15,2,19,4,21,1,25,5,28,3,30,1,9,2,7,5,1,2,33,3,35,2,0,0
	; 字母的类型的ASCII码
	letter db 65,65,65,65,65,65,65,65,65,65,65,65,65,0
	
	delay_timer db 0
	timecontrol db 18		; 用于控制速度快慢
	isend db 0				; 判断 
	isfirst db 0			; 是否第一次进入游戏
	gameover db 0			; 游戏结束标志

	; 用于显示分数
	message db 'your score:','$'
	score db 3 dup('0'),'$';分数的ascii码，用于显示
	score_b db 00h;分数的二进制码，用于运算

	; 用于游戏开始菜单
    message_welcome		db "* * * * * * * * * * * welcome * * * * * * * * * * *",'$'
    message_operation	db "*               How to play this game:            *",'$'
    message_operation1	db "*        Press key with corresponding letters     *",'$'
    message_operation2	db "*          Press correct key, get 1 point         *",'$'
	message_operation3	db "*       If the letter hit the ground, you lose    *",'$'
    message_operation4	db "*                    now,you can:                 *",'$'
    start_button		db "*           Press 'enter' to start the game       *",'$'
    end_button			db "*        Press 'esc' to quit(also in the game).   *",'$'
    message_end			db "* * * * * * * * * * * * * * * * * * * * * * * * * *",'$'
	message_blank		db "*                                                 *",'$'
	
	; 游戏难度
	message_easy		db "*                     1. EASY                     *",'$'
	message_mid			db "*                     2. MIDDLE                   *",'$'
	message_hard		db "*                     3. HARD                     *",'$'
	message_veryhard	db "*                     4. VERYHARD                 *",'$'
	message_choose		db "*                     choose:                     *",'$'

	; 进入游戏
	message_enter		db "*                     ENTERING                    *",'$'


	; 游戏结束
	message_over1 db "* * * * * * * * * * * * * *",'$'
	message_over2 db "*                         *",'$'
	message_over3 db "*        game over        *",'$'
	message_over4 db "*                         *",'$'
    message_over5 db "* * * * * * * * * * * * * *",'$'

	; 游戏音乐频率表/节拍表
    mus_freg	dw 330,294,262,294,3 dup (330)     ; 频率表
            	dw 3 dup (294),330,392,392
            	dw 330,294,262,294,4 dup (330)
            	dw 294,294,330,294,262,-1
    mus_time 	dw 6 dup (25),50                   ; 节拍表
            	dw 2 dup (25,25,50)
            	dw 12 dup (25),100

    mus_freg1	dw 294,-1
    mus_time1 	dw 25

    mus_freg2	dw 330,294,-1
    mus_time2 	dw 25,25

datas ends

stack segment stack
    db 200 dup(?)
stack ends



;--------------------------- 音乐宏地址 -----------------------------
ADDRESS MACRO A,B
    LEA SI,A
    LEA BP,DS:B
ENDM
;-------------------------------------------------------------------



codes segment
	assume cs:codes,ds:datas,ss:stack



;--------------------------- 主程序 ---------------------------------
start:
	; 用于分频
    mov al,34h		; 设控制字值 
    out 43h,al		; 写控制字到控制字寄存器 
    mov ax,0ffffh 	; 中断时间设置
    out 40h,al		; 写计数器0的低字节 
    mov al,ah		; al=ah 
    out 40h,al		; 写计数器0的高字节 

	mov ax,datas
	mov ds,ax
	mov ax,stack
    mov ss,ax

	call init			; 初始化函数，用于重置位置分数等
    call help_menu		; 调用帮助菜单 
	call choose_menu	; 选择难度菜单

	; 第一次进入游戏，调用随机数函数1生成字母
	cmp byte ptr ds:[isfirst],1
	jz j2
	call rand1
	mov byte ptr ds:[isend],0
j2:
	
	; 初始化isend标志
	mov byte ptr ds:[isend],0

	; 设置时钟中断
	xor ax,ax			; ax = 0
	mov ds,ax			; ds = 0
	mov word ptr ds:[20h],offset timer	; 设置时钟中断向量的偏移地址
	mov ax,cs 
	mov word ptr ds:[22h],ax			; 设置时钟中断向量的段地址=cs

	mov ax,datas
	mov ds,ax  
		 
    mov ah,00h		;设置显示方式为320*200彩色图形方式
    mov al,04h
    int 10h 

	;显示分数提示
	mov ah,02		
	mov bh,00
	mov dh,0
	mov dl,0
	int 10h
	mov ah,09
	mov dx,offset message
	int 21h
		    
	call play_letter		;画字母

;检测按键
lop:
	cmp byte ptr ds:[gameover],1	; 判断是否结束游戏
	jnz j17
	call endthegame
j17:
	mov ah,01						; 检测是否有按键，没有的话循环检测
	int 16h
	jz lop							; 没有按键，显示移动，再次检测
    
	; 从键盘读入字符          
    mov ah,0h	
    int 16h

	; 输入字符时播放音乐1
	push ax
	push bx
	push cx
	push dx
	push si
	push bp
	push di
	
	address mus_freg1, mus_time1
    call music

	pop di
	pop bp
	pop si
	pop dx
	pop cx
	pop bx
	pop ax

	; 遍历判断按键的字母是否存在
	push bx
	push cx
	push dx
	push si
	push di

	mov di,offset letter		; 字母
	mov si,offset letter_pos	; 字母位置

; 循环判断
judge_letter:
	cmp al,[di]
	jne j13
	;设置光标位置

	; 分数显示
	push ax
	push si
	push bx
	push dx
	xor ax,ax
	mov al,byte ptr ds:[score_b]
	add al,1
	mov byte ptr ds:[score_b],al
	mov si,offset score
	call b2asc
	mov ah,02
    mov bh,00
    mov dh,0
    mov dl,11
    int 10h
    mov ah,09
    mov dx,offset score
    int 21h

	pop dx
	pop bx
	pop si
	pop ax

	push ax
	push bx
	push cx
	push dx

	mov ah,02h
	mov bh,0
	mov dh,byte ptr [si+1]		
	mov dl,byte ptr [si]
	int 10h

	; 擦除字母
	mov ah,09h
	mov al,2	
	mov bl,0
	mov cx,1
	int 10h

	; 重新生成当前列的字母
	call rand2
	mov [di],bl

	; 重置位置
	mov byte ptr [si+1],1

	pop dx
	pop cx
	pop bx
	pop ax
	jmp j14

j13:
	inc di
	inc si
	inc si
	cmp byte ptr [si+1],0
	jnz judge_letter
	
	; 输入esc键，退出游戏
	cmp al,1bh
	je j5
	jmp j14
j5:
	call endthegame

j14:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
jmp lop
;-------------------------------------------------------------------



;---------------------------- Timer --------------------------------
; 用于画字母
timer:
	push ax
	mov al,byte ptr ds:[timecontrol]
	cmp byte ptr ds:[delay_timer],al
	pop ax
	jnz	goout
	mov byte ptr ds:[delay_timer],0
	call move_letter		; 移动字母
	call play_letter		; 画字母
goout:
	inc byte ptr [delay_timer]
	push ax
	mov al,20h			; al = eoi
	out 20h,al			; 发送eoi到主8529a
	out 0a0h,al			; 发送eoi到从8529a
	pop ax
	iret			; 从中断返回
;---------------------------------------------------------------------



;---------------------------- 初始化 ----------------------------------
init proc
	mov byte ptr ds:[delay_timer],0
	mov byte ptr ds:[timecontrol],18
	mov byte ptr ds:[score_b],00h
	mov byte ptr ds:[letter_pos],10
	mov byte ptr ds:[letter_pos+1],3
	mov byte ptr ds:[letter_pos+2],12
	mov byte ptr ds:[letter_pos+3],4
	mov byte ptr ds:[letter_pos+4],15
	mov byte ptr ds:[letter_pos+5],2
	mov byte ptr ds:[letter_pos+6],19
	mov byte ptr ds:[letter_pos+7],4
	mov byte ptr ds:[letter_pos+8],21
	mov byte ptr ds:[letter_pos+9],1
	mov byte ptr ds:[letter_pos+10],25
	mov byte ptr ds:[letter_pos+11],5
	mov byte ptr ds:[letter_pos+12],28
	mov byte ptr ds:[letter_pos+13],3
	mov byte ptr ds:[letter_pos+14],30
	mov byte ptr ds:[letter_pos+15],1
	mov byte ptr ds:[letter_pos+16],9
	mov byte ptr ds:[letter_pos+17],2
	mov byte ptr ds:[letter_pos+18],7
	mov byte ptr ds:[letter_pos+19],5
	mov byte ptr ds:[letter_pos+20],1
	mov byte ptr ds:[letter_pos+21],2
	mov byte ptr ds:[letter_pos+22],33
	mov byte ptr ds:[letter_pos+23],3
	mov byte ptr ds:[letter_pos+24],35
	mov byte ptr ds:[letter_pos+25],2
init endp
;---------------------------------------------------------------------



;---------------------------- 显示字母 -------------------------------
play_letter proc
	cmp byte ptr ds:[isend],1
	jz j3
	push ax
	push bx
	push cx
	push dx
	push si
	push di

	mov di,offset letter_pos
	mov si,offset letter

show_letter:
	; 设置光标位置
	mov ah,02h
	mov bh,0
	mov dh,byte ptr [di+1]	; y坐标
	mov dl,byte ptr [di]	; x坐标
	int 10h

	;显示字母
    mov ah,09h
    mov al,[si]
	mov bh,0
    mov bl,011111001b
    mov	cx,1
    int 10h

	inc si
	inc di
	inc di
	cmp byte ptr [di+1],0
	jnz show_letter
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
j3:
	ret
play_letter endp
;-------------------------------------------------------------------



;---------------------------- 移动字母 -------------------------------
move_letter proc
	cmp byte ptr ds:[isend],1
	jz j16
	push ax
	push bx
	push cx
	push dx
	push si
	push di
	mov si,offset letter_pos
	inc si
	mov di,offset letter_pos

erase_letter:	
	; 设置光标位置
	mov ah,02h
	mov bh,0
	mov dh,byte ptr [si]		; 行的位置
	mov dl,byte ptr [di]		; 列的位置
	int 10h
	; 擦除字母
    mov ah,09h
    mov al,2	
    mov bl,0	; 黑色，擦除字母
    mov cx,1
    int 10h
		
notexit:		
	;移动字母
	inc byte ptr [si]
	cmp byte ptr [si],25
	jnz goon
	mov byte ptr [si],1	;碰到边界
	mov byte ptr ds:[gameover],1
	mov byte ptr ds:[isfirst],1
goon:
	inc si
	inc si
	inc di
	inc di
	cmp byte ptr [si],0
	jnz j7
	jmp j8
j7:
	jmp erase_letter
j8:	
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
j16:
	ret
move_letter endp
;-------------------------------------------------------------------



;---------------------------- 延时1 ---------------------------------
delay proc 
	push dx
	push cx

	mov cx,02h
sleep2:
	mov dx,02f0h ; 计数次数

sleep1: 
	dec dx
	cmp dx,0
	jne sleep1

	dec cx
	cmp cx,0
	jne sleep2

	pop cx
	pop dx
	ret
delay endp
;-------------------------------------------------------------------



;---------------------------- 延时2 ---------------------------------
delay2 proc 
	push dx
	push cx

	mov cx,20h
sleep4:
	mov dx,0ffffh ; 计数次数

sleep3: 
	dec dx
	cmp dx,0
	jne sleep3

	dec cx
	cmp cx,0
	jne sleep4

	pop cx
	pop dx
	ret
delay2 endp
;-------------------------------------------------------------------



;---------------------------- 延时3 ---------------------------------
delay3 proc 
	push dx
	push cx

	mov cx,20h
sleep6:
	mov dx,00fffh ; 计数次数

sleep5: 
	dec dx
	cmp dx,0
	jne sleep5

	dec cx
	cmp cx,0
	jne sleep6

	pop cx
	pop dx
	ret
delay3 endp
;-------------------------------------------------------------------



;------------------------------ 帮助菜单 -----------------------------
help_menu proc
    call clearscreen
	mov ah,02
	mov bh,00
	mov dh,04
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_welcome
	int 21h	 
	
	mov ah,02
	mov bh,00
	mov dh,06
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_operation
	int 21h	 

	mov ah,02
	mov bh,00
	mov dh,08
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_operation1
	int 21h	 

	mov ah,02
	mov bh,00
	mov dh,10
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_operation2
	int 21h	 
	
	mov ah,02
	mov bh,00
	mov dh,12
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_operation3
	int 21h

	mov ah,02
	mov bh,00
	mov dh,14
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_operation4
	int 21h

	mov ah,02
	mov bh,00
	mov dh,16
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset start_button
	int 21h
	mov ah,02
	mov bh,00
	mov dh,18
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset end_button
	int 21h 
	
	mov ah,02
	mov bh,00
	mov dh,20
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_end
	int 21h

;检查是否有键被按下
checkbutton:
	mov ah,01
	int 16h
	jz checkbutton
	mov ah,0
	int 16h
	cmp ah,1ch ; 回车键
	je startthegame
	cmp al,1bh ; esc键
	je j9
	jmp j10
j9:
	mov ah,4ch
	int 21h
j10:
	jmp checkbutton
startthegame:
    call clearscreen ; 清屏
	ret
help_menu endp
;-------------------------------------------------------------------



;------------------------------ 难度菜单 -----------------------------
choose_menu proc
	mov ah,02
	mov bh,00
	mov dh,04
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_welcome
	int 21h

	mov ah,02
	mov bh,00
	mov dh,06
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_blank
	int 21h	 

	mov ah,02
	mov bh,00
	mov dh,08
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_easy
	int 21h	 
	
	mov ah,02
	mov bh,00
	mov dh,10
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_mid
	int 21h	 
	
	mov ah,02
	mov bh,00
	mov dh,12
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_hard
	int 21h	 
	mov ah,02
	mov bh,00
	mov dh,14
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_veryhard
	int 21h
	
	mov ah,02
	mov bh,00
	mov dh,16
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_choose
	int 21h	 

	mov ah,02
	mov bh,00
	mov dh,18
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_blank
	int 21h	 

	mov ah,02
	mov bh,00
	mov dh,20
	mov dl,13
	int 10h
	mov ah,09
	mov dx,offset message_end
	int 21h	 
	
; 检查是否有键被按下
checkbutton2:
	mov ah,01
	int 16h
	jz checkbutton2
	mov ah,0
	int 16h
	cmp al,'1'
	je easy
	cmp al,'2'
	je middle
	cmp al,'3'
	je hard
	cmp al,'4'
	je veryhard
	jmp checkbutton2

easy:
	mov byte ptr [letter_pos+12],0
	mov byte ptr [letter_pos+13],0
	;mov byte ptr [letter+6],0
	mov byte ptr [timecontrol],18
	jmp sta
middle:
	mov byte ptr [letter_pos+18],0
	mov byte ptr [letter_pos+19],0
	mov byte ptr [timecontrol],15 
	jmp sta
hard:
	mov byte ptr [timecontrol],11
	jmp sta
veryhard:
	mov byte ptr [timecontrol],2
	;mov byte ptr [letter+13],0
sta:    
	call clearscreen ;清屏
	ret
choose_menu endp
;-------------------------------------------------------------------



;--------------------------------清屏--------------------------------
clearscreen proc
	push ax
	push bx
	push cx
	push dx
	mov ah,06
	mov al,00
	mov bh,07
	mov ch,00
	mov cl,00
	mov dh,24
	mov dl,79
	int 10h
	pop dx
	pop cx
	pop bx
	pop ax
	ret
clearscreen endp
;-------------------------------------------------------------------



;---------------------- 二进制码转化为ascii码 -------------------------
b2asc proc
	pushf
	push bx
	push dx
	mov bx,10
	mov byte ptr [si],'0'
	inc si
	mov byte ptr [si],'0'
	inc si
	mov byte ptr [si],'0'
	;add si,2 ;这个视有几个ascii码而定，显示三位时定为二
b2a_loop:
    xor dx,dx
    div bx
    or dx,30h
    mov [si],dl
    dec si
    cmp ax,0
    ja b2a_loop
    pop dx
    pop bx
    popf
    ret
b2asc endp
;-------------------------------------------------------------------



;--------------------------- 结束游戏 --------------------------------
endthegame proc
	mov ah,00h
	mov al,00h
	int 10h
	; 设置标记
	mov byte ptr ds:[isend],1
	mov byte ptr ds:[isfirst],1
	; 如果gameover标记为1则显示gameover界面
	cmp byte ptr ds:[gameover],1
	jnz j15
	call clearscreen ;清屏

	mov ah,02
	mov bh,00
	mov dh,7
	mov dl,6
	int 10h
	mov ah,09
	mov dx,offset message_over1
	int 21h	 

	mov ah,02
	mov bh,00
	mov dh,9
	mov dl,6
	int 10h
	mov ah,09
	mov dx,offset message_over2
	int 21h	 

	mov ah,02
	mov bh,00
	mov dh,11
	mov dl,6
	int 10h
	mov ah,09
	mov dx,offset message_over3
	int 21h	

	mov ah,02
	mov bh,00
	mov dh,13
	mov dl,6
	int 10h
	mov ah,09
	mov dx,offset message_over4
	int 21h	

	mov ah,02
	mov bh,00
	mov dh,15
	mov dl,6
	int 10h
	mov ah,09
	mov dx,offset message_over5
	int 21h

	; 调用死亡音乐
	address mus_freg, mus_time
    call music
	;call delay2

	j15: 
	call clearscreen
	
	; 清除gameover标记
	mov byte ptr ds:[gameover],0
    mov ax,4f02h		; 设置显示方式为1024*768彩色图形方式
    mov bx,101h
    int 10h 

	jmp start
endthegame endp
;-------------------------------------------------------------------



;----------------------------- 随机数 -------------------------------
rand proc
    push cx
    push dx
    push ax
    sti
    mov ah,0			; 读时钟计数器值
    int 1ah
    mov ax,dx			; 清高6位
    and ah,3
    mov dl,26			; 除26，产生0~25余数
    div dl
    mov bl,ah			; 余数存bx，作随机数
    add bx,65			; 加65获得ASCII码
	pop ax
    pop dx
    pop cx
    ret
rand endp
;-------------------------------------------------------------------



;----------------------------- 随机数1 ------------------------------
; 初始化所有字母
rand1 proc
    push cx
    push dx
	push bx
    push ax
	push si
	push di
	mov si,offset letter
	mov di,13
get_rand:
	call rand
	mov [si],bx
	inc si
	dec di
	call delay3
	cmp di,0
	jnz get_rand
	pop di
	pop si
	pop ax
	pop bx
    pop dx
    pop cx
    ret
rand1 endp
;-------------------------------------------------------------------



;----------------------------- 随机数2 ------------------------------
; 产生单独的随机数
rand2 proc
    push cx
    push dx
    push ax
    sti
    mov ah,0
    int 1ah
    mov ax,dx
    and ah,3
	add al,[di]
    mov dl,26
    div dl
    mov bl,ah
    add bx,65
	pop ax
    pop dx
    pop cx
    ret
rand2 endp
;-------------------------------------------------------------------



;------------------------------- 发声 -------------------------------
gensound proc near
    push ax
    push bx
    push cx
    push dx
    push di

    mov al, 0b6H
    out 43h, al
    mov dx, 12h
    mov ax, 348ch
    div di
    out 42h, al

    mov al, ah
    out 42h, al

    in al, 61h
    mov ah, al
    or al, 3
    out 61h, al
wait1:
    mov cx, 3314
    call waitf
delay1:
    dec bx
    jnz wait1

    mov al, ah
    out 61h, al

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret 
gensound endp
;-------------------------------------------------------------------



;------------------------------- 等待 -------------------------------
waitf proc near
    push ax
waitf1:
    in al,61h
    and al,10h
    cmp al,ah
    je waitf1
    mov ah,al
	loop waitf1
    pop ax
    ret
waitf endp
;-------------------------------------------------------------------



;---------------------------- 发声调用函数 ---------------------------
music proc near
    xor ax,ax
freg:
    mov di,[si]
    cmp di,0FFFFH
    je end_mus
    mov bx,ds:[bp]
    call gensound
    add si,2
    add bp,2
    jmp freg
end_mus:
    ret
music endp
;-------------------------------------------------------------------


codes ends
end start