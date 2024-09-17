assume cs:code, ds:data, ss:stack

stack segment
    dw 16 dup(0) ;; 16*16 bit
stack ends

;; programme data
data segment
    fh dw 0 ;; file handle
    buffer db 0 ;; buffer of rawPixelData
    padding db 0 ;; BytePadding
    ftd db 14 dup(0) ;; file type data
    iid db 40 dup(0) ;; image information data
    ;; colorPallet, unnecessary
    ;; rawPixelData, read when write
    f_err_str db ' Can not found the file, or is not a img.', '$'
    d_err_str db ' Image too big, or using 4bit in a big img.', '$'
    pgm_info db ' A programme for display image in DOS.', 0dh, 0ah
    db ' The programme only support 4bit and 8bit color by the reason of DOS.', 0dh, 0ah
    db ' The image should be smaller than 1024 * 768 if it is 8bit.', 0dh, 0ah
    db ' And should be smaller than 640 * 200 if it is 4bit.', 0dh, 0ah
    db ' For get a support image you can use this converter:', 0dh, 0ah
    pgm_info_end db '   BmpConverter - v2.0', '$'
    fname db 128 dup(0)
data ends

code segment

;; Set the displayModo with the height & witdh of img.
;; Modo 0eh / 13h if the img was smaller than 640*200.
;; Modo 104h / 105h if it's bigger than.
;; Go to display_err if the img is out of 1024 * 768.
;; dx = height , cx = witdh
;; word ptr ds:iid[0eh] = color depth (4 or 8)
set_display_modo:
    push ax
    push bx
    
    cmp dx, 768
    ja display_err
    cmp cx, 1024
    ja display_err
    
    cmp dx, 200
    ja big
    cmp cx, 640
    ja big
    
    mov ax, 0013h
    
    cmp word ptr ds:iid[0eh], 8
    je set_modo
    ;; 4bit
    sub ax, 6
    jmp set_modo
    
big:mov ax, 4f02h
    mov bx, 105h
    
    cmp word ptr ds:iid[0eh], 4
    je display_err
set_modo:
    int 10h
    pop bx
    pop ax
    ret
    

file_err_checker:
    push cx
    
    pushf
    pop cx
    and cx, 00000001b ;; check cf of flag
    
    jcxz no_err ;; jump to, if success
file_err: 
    mov ax, offset f_err_str
    jmp short ed
no_err:
    pop cx
    ret


display_err:
    mov ax, offset d_err_str
    jmp short ed

print_info:
    mov ah, 09h
    mov dx, offset pgm_info
    int 21h
    mov ax, 3
    jmp ed

edd: ;; exit that should reset display modo
    mov ah, 00h
    mov al, 03h
    int 10h
ed: 
    cmp ax, 0003
    je qut
        mov dx, ax
        mov ah, 09h
        int 21h
qut:mov ax, 4c00h;
    int 21h

main:
    mov ax, stack
    mov ss, ax
    mov sp, 64 ;; 256
    ;; ds -> psp
    mov ax, data
    mov es, ax
    
    ;; get file name
    mov si, 82h
    mov di, offset fname
    cld
    
    ;; if param is empty
    mov al, [si]
    cmp al, 00h
    jne mfn
    mov ax, data
    mov ds, ax
    jmp short file_err
    
    ;; move file name
mfn:movsb
    mov al, [si]
    cmp al, 0dh
    jne mfn
    
    mov ax, es
    mov ds, ax
    
    ;; -h command, print programme info
    mov ax, word ptr ds:[fname]
    cmp ax, 682dh
    je print_info
    
    ;; open file
    mov ah, 3dh
    mov al, 0
    mov dx, offset fname
    int 21h
    mov fh, ax ;; save file handle
    call file_err_checker
    
    ;; read bmp
    mov bx, ax
    mov di, offset ftd
    mov si, offset iid
    call read_bmp
    
    mov ax, word ptr ds:[ftd]
    cmp ax, 4d42h
    je z
    jmp file_err ;; isn't bmp file.
    
z:  cmp word ptr ds:iid[0eh], 04
    je spt
    cmp word ptr ds:iid[0eh], 08
    je spt
    jmp file_err ;; only support 4bit and 8bit
    
spt: ;; supported bmp file
    mov dx, word ptr ds:ftd[0ah];; start of rawPixelData
    mov cx, word ptr ds:ftd[0ch]
    mov ah, 42h
    mov al, 0
    int 21h
    call file_err_checker
    
    
    ;; calc bytes to padding
    mov ax, word ptr ds:iid[4]
    ;; 8bit, width in byte = width
    cmp word ptr ds:iid[0eh], 08
    je bpa
    
    mov bx, 2
    div bx
    cmp dx, 0
    je bpa
    inc ax ;; ax = width in byte
bpa:mov dx, 0
    mov bx, 4
    div bx
    cmp dx, 0
    je sb
    mov al, 4
    sub al, dl
    mov padding, al
    
    ;; show bmp
sb: mov cx, word ptr ds:iid[4] ;; width of img
    mov dx, word ptr ds:iid[8] ;; height of img
    call set_display_modo
    
    y:  
        dec dx
        mov cx, 0
        x:
            mov bx, fh
            call read_pixels
            
            cmp word ptr ds:iid[0eh], 04
            je bit_4
            ;; 8bit
            push cx
            mov cl, 4
            shl al, cl
            add al, ah
            pop cx
            
            call play_pixel
            inc cx
            jmp bxe
            
       bit_4:
            call play_pixel
            inc cx
            
            cmp cx, word ptr ds:iid[4]
            je xed
            
            mov al, ah
            call play_pixel
            inc cx
            
        ;; before x end
        bxe:cmp cx, word ptr ds:iid[4]
            jb x
        xed:
        
        push dx
        ;; skip padding byte
        mov dl, padding
        mov dh, 0
        mov cx, 0
        mov ax, 4201h
        int 21h
        
        pop dx
        
        cmp dx, 0
        jne y
    yed:

quit:    
    mov ah, 08h
    int 21h
    cmp al, 71h
    jne quit
    mov ah, 08h
    int 21h
    cmp al, 0dh
    jne quit
    ;; press 'q' and 'enter' to quit

    jmp near ptr edd

;; write a pixel to the screen
;; (cx, dx) = (x, y)
;; al = color
play_pixel:
    push dx
    push cx
    push bx
    push ax
    
    mov ah, 0ch
    mov bx, 0
    int 10h
    
    pop ax
    pop bx
    pop cx
    pop dx
    ret

;; read 2 pixel of bmp file
;; param:
;;  bx = file handle
;; return:
;;  al = color of first pixel
;;  ah = color of secund pixel
read_pixels:
    push cx
    push dx

    mov ah, 3fh
    mov cx, 1
    mov dx, offset buffer
    int 21h
    call file_err_checker
    
    mov ah, buffer
    mov al, ah
    mov cl, 4
    shr al, cl
    and ah, 00001111b
    
    pop dx
    pop cx
    ret

;; Read a bmp file
;; bx, file handle
;; ds:di, file type data, 14 bytes
;; ds:si, image information data, 40 bytes
read_bmp:
    push ax
    push cx
    push dx

    ;; read ftd
    mov ah, 3fh
    mov cx, 14
    mov dx, di
    int 21h
    call file_err_checker
    
    ;; read iid
    mov ah, 3fh
    mov cx, 40
    mov dx, si
    int 21h
    call file_err_checker
    
    pop dx
    pop cx
    pop ax
    ret

code ends

end main