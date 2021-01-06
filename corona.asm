OFF		EQU 0
ON		EQU 1
MAXLONG         EQU 500         ; Taille max du virus
EOS             EQU '$'         ; Fin de la chaine
VIDE           	EQU ' '         ; Vide
LF              EQU 10          ; Ligne de bacteries
CR              EQU 13          ; Retour chariot
KEYBD           EQU 16H         ; Interruption du clavier
VIDEO           EQU 10H         ; Interruption video
DOSFUNCT        EQU 21H         ; Interruption fonction DOS
PRINTER         EQU 17H         ; Interruption des entrés / sortis 
CLOCK           EQU 1AH         ; Interruption horloge
CORPS           EQU 15          ; Segment du corps
VIRUSCOLOR      EQU 100B        ; Couleur du virus (rouge)
MUR            	EQU 219		; Mur
BACT            EQU 42		; Bacteries
AIR             EQU 32		; Air

;--------------
; MACRO PRINT |
;--------------

PRINT MACRO STRING
        	LEA DX,STRING
        	MOV AH,9
        	INT DOSFUNCT
        	ENDM
        	
;-------------------------
; MACRO NETTOYAGE SCREEN |
;-------------------------

CLRSCR MACRO
		CALL CLEAR_SCR
        	ENDM

;-------------------------
; MACRO D'ATTENTE TOUCHE |
;-------------------------

ATT_TOUCHE MACRO
        	LOCAL WEIGHT
WEIGHT: 	CALL TOUCHE_PRESS
        	JZ WEIGHT
        	ENDM

;----------------------------------
; MACRO POSITIONNEMENT DU CURSEUR |
;----------------------------------

SET_CURSOR MACRO ROW,COL,STATE		; Affecte AH,BH,CX,DX
;Condition
        	IFNB <STATE>            ; Positionne le curseur et le tourne
           	  IFE STATE-ON          ; ON / OFF
              	  MOV CX,0607H          ; Curseur 'ON' pour la couleur
              	  MOV AX,ES
              	  CMP AX,0B800H         ; On s'assure d'utiliser la couleur
              	  JE $+5
              	  MOV CX,0C0DH          ; Curseur 'ON' pour mono
           	ELSE
              	  MOV CX,2020H          ; Sinon curseur 'OFF'
           	ENDIF
           	MOV AH,1
           	INT VIDEO               ; Définir le type de curseur
        	ENDIF
        	MOV DH,ROW
        	MOV DL,COL
        	MOV BH,0
        	MOV AH,2
        	INT VIDEO               ; Définir la position du curseur
        	ENDM

;----------------
; STOCKAGE PILE |
;----------------

STACK SEGMENT STACK           		; Segment de la pile
        	DW 128 DUP (?)          ; Autorise 256 octets pour la pile
STACK ENDS

;--------------
; DATA DU JEU |
;--------------

DATA    	SEGMENT
        	VITESSE DW ?                  	; Nombre à partir de 0(rapide)...60(lent)
        	TAILLE DW 1                     ; Nombre de segments
        	DIR DW 0
        	NEW_DIR DW -162,-160,-158,0
                	DW -2,0,2,0
                	DW 158,160,162
        	SEED DW ?               	; Pour les nombres aléatoires
        	SCORE DW ?
        	ENDLIG DB ?
        	ENDCOL DB ?
        	GAME_MSG DB 'CORONAWAR',EOS
        	SCORE_MSG DB 'SCORE:',EOS
        	GAMEOVER DB 'GAME OVER',EOS
        	MSG1 DB 'CHOPES LE CORONA !',EOS
			MSG2 DB 'ATTRAPE TOUTES LES BACTERIES POUR GRANDIR',EOS
			MSG3 DB '--JEU REALISE PAR MAXENCE GIRON ET DORIAN VENDETTI--',EOS
        	POSITION DW MAXLONG DUP(?)
        	TETE EQU POSITION+2
        	TMP DB ?
DATA ENDS

;------------
; PROGRAMME |
;------------

CODE SEGMENT
PROGRAM PROC FAR
        	ASSUME CS:CODE, DS:DATA, SS:STACK

PRG:    	PUSH DS			; Permettre le retour vers DOS
        	MOV AX,0
        	PUSH AX
		MOV AX,DATA             ; Mettre en place DS pour le segment de données
        	MOV DS,AX

START:  	CALL INIT       	; Dessine l'écran, initialise les vars, met les bacteries

MAIN:   	CALL OBT_POS       	; Regarde ce que la tête va toucher (AL=Données de l'écran)
        	CMP AL,AIR
        	JE MOVE
        	CMP AL, BACT
        	JNE ENDGAME     	; Tout sauf les bacteries et l'air => FIN 
        	CALL MANGER

MOVE:   	CALL DEPLAC_VIRUS 	; Déplace le virus en fonction de la direction
        	CALL GET_INPUT  	; Obtenir la direction de l'INPUT
        	JC EXCAPE
        	MOV DX,VITESSE
        	CALL DELAIS
        	JMP MAIN

ENDGAME:	MOV TMP,255
        	MOV CX,0303H
        	MOV BL,MUR
        	CLRSCR
        	SET_CURSOR 12,36
        	PRINT GAMEOVER
        	SET_CURSOR 14,25
        	PRINT SCORE_MSG
        	CALL RETOUR_SCORE

BORDUREFIN:  	MOV CX,0H
			MOV BH,100B     
        	MOV BL,MUR 
        	CALL BORDURE
        	MOV AX,0C01H    	; Clear le buffer et obtient la touche
        	INT DOSFUNCT
        	CMP AL,27       	; Echap
        	JNE START        

EXCAPE: 	CLRSCR
        	SET_CURSOR 0,0,ON
        	RET
PROGRAM ENDP

;---------------
; SOUS-ROUTINE |
;---------------

INIT PROC NEAR
        	CLRSCR
        	SET_CURSOR 0,0,OFF      ; Mettre le curseur en OFF dans le menu

;-------------------------------
; Détermine quel écran utiliser;
;-------------------------------

        	ASSUME ES:NOTHING
        	MOV CX,0B800H           ; Prendre des couleurs
        	MOV AH,15              	; Mode de lecture vidéo (MONO=7)
        	INT 10H			; Dans 10H
        	CMP AL,7
        	JNE USECGA
        	SUB CX,800H

USECGA: 	MOV ES,CX

;------------------------------
;Initialisation des Variables |
;------------------------------

        	MOV AH,0                ; Timer de lecture (DX = MOT BAS)
        	INT CLOCK
        	MOV SEED,DX             ; Mettre une valeur de départ random à l'horloge
        	MOV DIR,0   	        ; Le virus démarre à l'arrêt
        	MOV TAILLE,1            ; Le virus démarre avec uniquement sa tête
        	MOV VITESSE,60          ; Initialiser la vitesse
        	MOV SCORE,0		; Initialiser le score

        	SET_CURSOR 2,3
        	PRINT GAME_MSG          ; Affiche le titre du jeu

        	MOV BH,AL
EFFET: 		MOV CX,0H
			MOV BH,110b           	; Mode d'affichage des titres
        	MOV BL,MUR
        	CALL BORDURE
        	MOV DX,40
        	CALL DELAIS
        	CALL TOUCHE_PRESS         ; Jusqu'à ce qu'une touche soit appuyée
        	JZ EFFET

        	SET_CURSOR 12,33 
        	PRINT MSG1
        	SET_CURSOR 13,20
        	PRINT MSG2
        	SET_CURSOR 14,14 
        	PRINT MSG3
        	MOV AH,1
        	INT DOSFUNCT
        	
        	CALL DELAIS
        	CALL TOUCHE_PRESS
        	CLRSCR
        	JNE PLAY
        	
;-------------------
; LANCEMENT DU JEU |
;-------------------

PLAY:   	MOV CX,0H
        	MOV BH,110b             ; Bordure en orange
        	MOV BL,MUR
        	STC
        	CALL BORDURE

        	CALL RND_POS            ; AX = 0..3998
        	MOV TETE,AX             ; Le virus apparaît aléatoirement
        	CALL DEPLAC_VIRUS         ; Place la tête à l'endroit désigné
        	MOV CX,15               ; CX = Nombre de nourritures au début de la partie
        	CALL SPAWN_BACT
        	SET_CURSOR 24,34        ; Affiche le mot "Score" en bas de l'écran
        	PRINT SCORE_MSG
        	CALL RETOUR_SCORE       ; Affiche le score actuel
        	RET
INIT ENDP

;--------------------------
; Fonction touche préssée |
;--------------------------

TOUCHE_PRESS PROC NEAR    	; Retourne Z si aucune touche est appuyée, NZ sinon
        	MOV AH,1        ; Touche appuyée ?
        	INT KEYBD
        	JZ OUT1         ; Non, retourne ZF=1
        	PUSHF
        	MOV AH,0        ; Oui, la lire et retourne ZF=0
        	INT KEYBD       ; Retourne AL = Code ASCII 
        	POPF

OUT1:   	RET

TOUCHE_PRESS ENDP

;-----------------------
; Nettoyage de l'écran |
;-----------------------

CLEAR_SCR PROC NEAR             	; Nettoie l'écran (Affecte AX,BH,CX,DX)
        	MOV CX,0000             ; 0,0 = Coin en haut à gauche
        	MOV DX,184FH            ; 18H,4FH = 24,79 = Coin en bas à droite
        	MOV AX,0600H            ; Définit le nettoyage d'écran
        	MOV BH,100B             ; Remplir la mémoire couleur en rouge
        	INT VIDEO
        	RET
CLEAR_SCR ENDP

;----------
; BORDURE |
;----------

BORDURE PROC NEAR  			; CX = Ligne de départ,COL BX = ATTRIB,CHAR
                  			; Dessine la bordure sur un écran de même couleur (Si carry flag CLR)
                  			; Couleurs différentes (Si carry flag set)
        	PUSHF                   ; Sauvegarde le mot dans le carry flag
BO1:    	CALL CONTOUR
        	POP AX                  ; Obtenir le contenu des carry flag
        	PUSH AX                 ; Et remettre sur la pile
        	AND AX,1B               ; Efface tous les bits sauf le carry flag
        	ADD BH,AL               ; Changement de couleur UNIQUEMENT si le carry flag a été défini
        	AND BH,0FH              ; On s'assure de ne peux toucher à la couleur de fond
        	DEC CL
        	DEC CH                  ; Se déplace vers l'extérieur en allant vers le bord de l'écran
        	JNS BO1                 ; Répéter jusqu'à ce qu'il y est dépacement de la bordure extérieure
        	POPF                    ; Renvoie le mot original du carry flag
        	RET
BORDURE ENDP

;----------
; CONTOUR |
;----------

CONTOUR PROC NEAR 				; Envoie CH=START LIG, CL=START COL, BL = CHAR, BH=ATTRIB
                  				; Dessine un rectangle où (CH,CL) est le coin supérieur gauche
        	MOV WORD PTR ENDLIG,4F18H       ; On suppose la ligne de fin, COL = (24,79)
        	SUB ENDLIG,CH                   ; Ajuster en fonction de la ligne de départ, COL
        	SUB ENDCOL,CL
        	MOV DL,CL               	; POUR DL = BEGCOL Vers ENDCOL faire

BOUCLE1:  	MOV DH,CH               	;       LIG = BEG_LIG
        	CALL TERRAIN               	;       TERRAIN (LIG,DL)
        	MOV DH,ENDLIG           	;       LIG = END_LIG
        	CALL TERRAIN               	;       TERRAIN (LIG,DL)
        	INC DL                  	; NEXT DL
        	CMP DL,ENDCOL
        	JBE BOUCLE1

        	MOV DH,CH               	; POUR DH = BEGLIG Vers ENDLIG Faire
BOUCLE2:  	MOV DL,CL               	;       COL = BEGCOL
        	CALL TERRAIN               	;       TERRAIN (DH,COL)
        	MOV DL,ENDCOL           	;       COL = ENDCOL
        	CALL TERRAIN               	;       TERRAIN (DH,COL)
        	INC DH                  	; NEXT DH 
        	CMP DH,ENDLIG
        	JBE BOUCLE2
        	RET
CONTOUR ENDP

;----------
; TERRAIN |
;----------

TERRAIN PROC NEAR                  	; SEND DH=LIG,DL=COL,BL=CHAR,BH=ATTRIBUTE
        	PUSH DX
        	MOV AL,160
        	MUL DH                  ; AX = AL*DH
        	MOV SI,AX               ; SI = LIG*160.....
        	MOV DH,0
        	SHL DL,1				;
        	ADD SI,DX               ; .....+ COL*2
        	MOV ES:[SI],BL          ; Donner un caractère à TERRAIN
        	MOV ES:[SI+1],BH        ; Avec un attribut donné
        	POP DX
        	RET
TERRAIN ENDP

;------------------------------
; GENERER UN NOMBRE ALEATOIRE |
;------------------------------

RANDOM PROC NEAR        		; Retourne AX = aléatoire
        	PUSH BX
        	MOV AX,SEED
        	MOV BX,25173
        	MUL BX
        	ADD AX,13849
        	MOV SEED,AX
        	POP BX
        	RET
RANDOM ENDP

;---------------------
; POSITION ALEATOIRE |
;---------------------

RND_POS PROC NEAR       	; Retourne AX = position "libre" aléatoire
                        	; I.E. AX = PAIR # 0..3998 pointant vers "AIR"
        	CALL RANDOM
        	AND AX,4094     ; Mettre AX à sa place et rendre égal
        	CMP AX,3998
        	JAE RND_POS
        	MOV BX,AX
        	CMP BYTE PTR ES:[BX],AIR
        	JNE RND_POS
        	RET
RND_POS ENDP

;---------------------------------
; FAIRE APPARAITRE DES BACTERIES |
;---------------------------------

SPAWN_BACT PROC NEAR          			; CX = Nombre de bactéries à mettre
        	CALL RND_POS                    ; Choisir un endroit au hasard pour les bactéries
        	MOV BX,AX
        	MOV BYTE PTR ES:[BX],BACT       ; Dessiner les bactéries à l'écran
        	CALL RANDOM                     ; Choisir un nombre aléatoire pour la couleur
        	AND AL,110B
        	OR AL,101B          		; Couleurs possibles :magenta, gris clair
        	MOV BYTE PTR ES:[BX+1],AL       ; Colorier les bactéries
        	LOOP SPAWN_BACT                   ; Répéter pour toutes les bactéries
        	RET
SPAWN_BACT ENDP

;----------------------------
; POUR MANGER LES BACTERIES |
;----------------------------

MANGER PROC NEAR          		; Appeler lorsque le virus rentre en collision avec une bactérie	
        	MOV AX,TAILLE       	; Score pour manger des bactéries : peu importe la taille actuelle
        	ADD SCORE,AX
        	CALL RETOUR_SCORE

        	TEST TAILLE,111B     	; Chaque fois que la taille est un multiple de 8  
        	JNZ GARDER_VITESSE				; ==> Rendre le virus + rapide
        	CMP VITESSE,10
        	JBE GARDER_VITESSE    	; Sauf si la vitesse est de 10 (Vitesse maximale)
        	SUB VITESSE,1

GARDER_VITESSE: 	
			CMP TAILLE,MAXLONG   	; Le virus est-il à sa taille maximale ?
        	JBE GRANDIR        	; Une fois qu'il a atteint le MAXLONG il perd son corps
        	MOV TAILLE,0        	; Et devient juste une tête comme au début du jeu

GRANDIR:   	INC TAILLE         	; La consommation de bactéries entraîne une augmentation de la taille de 1% sur le virus
        	MOV CX,1          	; Mettre une autre bactérie à l'écran pour remplacer celle qui a été consommée
        	CALL SPAWN_BACT
        	RET
MANGER ENDP

;---------------------------------
; OBTENIR LA POSITION DE LA TETE |
;---------------------------------

OBT_POS PROC NEAR          		; Envoyer DIR, retourner AL = ce que le virus touchera après
                        		; Fixe également BX = emplacement de la nouvelle tête
        	MOV BX,TETE             ; Obtenir la position actuelle de la tête
        	ADD BX,DIR              ; Ajouter une valeur de direction
        	MOV AL,ES:[BX]          ; Voir ce qu'il en est de la nouvelle position de la tête
        	CMP DIR,0               ; Si DIR=0, alors pas de déplacement
        	JNE OUT2
        	MOV AL,AIR              ; Donc on retourne NULL (AIR)
OUT2:   	RET
OBT_POS ENDP

;-----------------------
; DEPLACEMENT DU VIRUS |
;-----------------------

DEPLAC_VIRUS PROC NEAR    		             ; Déplace le virus d'un espace en fonction de sa direction

;--D'abord effacer la queue
        	MOV SI,TAILLE                        ; Mettre le pointeur à la queue
        	SHL SI,1
        	MOV BX,POSITION[SI]                  ; Obtenir la localisation de la queue sur l'écran
        	MOV BYTE PTR ES:[BX],AIR             ; Mettre "AIR" à la localisation
        	MOV BYTE PTR ES:[BX+1],111B          ; Régler la couleur blanc sur le noir

;--Déplacer le corps vers l'avant
        	CALL DEPLAC_CORPS                    ; Déplacement du corps

;--Dessiner la tête sur la nouvelle position
        	CALL OBT_POS                            ; Obtenir la localisation de la nouvelle tête (BX)
        	MOV BYTE PTR ES:[BX],CORPS           ; Dessine la tête du virus
        	MOV BYTE PTR ES:[BX+1],VIRUSCOLOR    ; Couleur du virus
        	MOV TETE,BX                          ; Sauvegarde la nouvelle position de la tête
        	RET

DEPLAC_CORPS:      				     ; Pour C = TAILLE > 1 Faire
                				     ; Position(C) := Position(C-1)
        	MOV AX,POSITION[SI]
        	MOV POSITION[SI+2],AX
        	DEC SI
        	DEC SI
        	JNZ DEPLAC_CORPS
        	RET
DEPLAC_VIRUS ENDP

;--------------------
; OBTENIR LA TOUCHE |
;--------------------

GET_INPUT PROC NEAR     		; Permet de modifier la direction du virus                        	
        	CALL TOUCHE_PRESS 	; Regarde si une touche est appuyée
        	JZ KEEPSAME     	; Non, garder la même direction
                        		; Oui, AL=ASCII, AH=SCAN
        	CMP AL,27       	
        	STC             	; Définit si l'utilisateur veut quitter le programme
        	JE GETOUT
        	CMP AH,71       	; Code ASCII #7 (En haut à gauche)
        	JB KEEPSAME
        	CMP AH,81       	; Code ASCII #3 (En bas à droite)
        	JA KEEPSAME
        	SUB AH,71
        	MOV BL,AH       	; BL = 0..10
        	SHL BL,1        	; BL = 0..20
        	MOV BH,0
        	MOV AX,NEW_DIR[BX] 	; Nouvelle direction correspond à la touche appuyée
        	CMP AX,0        	; Si AX=0 il n'y a pas de direction
        	JE KEEPSAME     	; Ducoup pas de direction en zéro
                        		; Mais plutôt garder l'ancienne direction
        	MOV DIR,AX
KEEPSAME:	CLC            		
GETOUT: 	RET
GET_INPUT ENDP

;----------
;  DELAIS |
;----------

DELAIS PROC NEAR                 	
        	PUSH CX
        	PUSH DX					; Envoi DX=0(rapide)...60(lent)
        	MOV AX,DIR
        	ADD AX,1                ; Si ce n'est pas horizontal alors
                                	; AX sera plus grand que 4
        	CMP AX,4
        	JBE D0
        	MOV CX,DX
        	SHR CX,1                ; Vertical est 3/2 plus lent
        	ADD DX,CX

D0:     	MOV AX,500
        	MUL DX                  ; AX = 500*(DX)
        	MOV CX,AX

D1:     	LOOP D1			
        	POP DX
        	POP CX
        	RET
DELAIS ENDP

;---------------------------------
; RETOUR DU SCORE POUR AFFICHAGE |
;---------------------------------

RETOUR_SCORE PROC NEAR
        	MOV SI,10
        	MOV AX,SCORE

RSBOUCLE: 	MOV DX,0
        	MOV BX,10
        	DIV BX          			; AX = QUOT, DX = RMDR
        	ADD DL,'0'
        	MOV ES:[3920+SI],DL
        	MOV BYTE PTR ES:[3920+SI+1],1111B	; Blanc
        	MOV BYTE PTR ES:[3908+SI+1],1111B
        	SUB SI,2
        	JNS RSBOUCLE
        	RET
RETOUR_SCORE ENDP

;----------------
; FIN PROGRAMME |
;----------------

CODE    	ENDS                    ; Fin du segment
        	END PRG                 ; Fin du programme
