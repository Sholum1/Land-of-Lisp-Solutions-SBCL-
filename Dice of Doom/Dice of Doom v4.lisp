(load "Dice of Doom v3")

(defparameter *num-players* 4)
(defparameter *die-colors* '((255 63 63) (63 63 255) (63 255 63) (255 63 255)))

(defparameter *max-dice* 5)
(defparameter *ai-level* 2)

(defun board-attack-fail (board player src dst dice)
  (declare (ignore dst dice))
  (board-array (loop for pos from 0
		     for hex across board
		     collect (if (eq pos src)
				 (list player 1)
				 hex))))

(defun attacking-moves (board cur-player spare-dice)
  (labels ((player (pos)
	     (car (aref board pos)))
	   (dice (pos)
	     (cadr (aref board pos))))
    (lazy-mapcan (lambda (src)
		   (if (eq (player src) cur-player)
		       (lazy-mapcan
			(lambda (dst)
			  (if (and (not (eq (player dst) cur-player))
				   (> (dice src) 1))
			      (make-lazy (list (list (list src dst)
						     (game-tree (board-attack
								 board
								 cur-player
								 src
								 dst
								 (dice src))
								cur-player
								(+ spare-dice
								   (dice dst))
								nil)
						     (game-tree (board-attack-fail
								 board
								 cur-player
								 src
								 dst
								 (dice src))
								cur-player
								(+ spare-dice
								   (dice dst))
								nil))))
			      (lazy-nil)))
			(make-lazy (neighbors src)))
		       (lazy-nil)))
		 (make-lazy (loop for n below *board-hexnum* collecting n)))))

(defun roll-dice (dice-num)
  (let ((total (loop repeat dice-num
		     sum (1+ (random 6)))))
    (fresh-line)
    (format t "On ~a dice rolled ~a. " dice-num total)
    total))

(defun roll-against (src-dice dst-dice)
  (> (roll-dice src-dice) (roll-dice dst-dice)))

(defun pick-chance-branch (board move)
  (labels ((dice (pos)
	     (cadr (aref board pos))))
    (let ((path (car move)))
      (if (or (null path) (roll-against (dice (car path))
					(dice (cadr path))))
	  (cadr move)
	  (caddr move)))))

(defun handle-human (tree)
  (fresh-line)
  (princ "choose your move: ")
  (let ((moves (caddr tree)))
    (labels ((print-moves (moves n)
	       (unless (lazy-null moves)
		 (let* ((move (lazy-car moves))
			(action (car move)))
		   (fresh-line)
		   (format t "~a. " n)
		   (if action
		       (format t "~a -> ~a" (car action) (cadr action))
		       (princ "end turn")))
		 (print-moves (lazy-cdr moves) (1+ n)))))
      (print-moves moves 1))
    (fresh-line)
    (pick-chance-branch (cadr tree) (lazy-nth (1- (read)) moves))))

(defun handle-computer (tree)
  (let ((ratings (get-ratings (limit-tree-depth tree *ai-level*) (car tree))))
    (pick-chance-branch
     (cadr tree)
     (lazy-nth (position (apply #'max ratings) ratings) (caddr tree)))))

(defparameter *dice-odds* #(#(0.84 0.97 1.0 1.0)
			    #(0.44 0.78 0.94 0.99)
			    #(0.15 0.45 0.74 0.91)
			    #(0.04 0.19 0.46 0.72)
			    #(0.01 0.06 0.22 0.46)))

(defun get-ratings (tree player)
  (let ((board (cadr tree)))
    (labels ((dice (pos)
	       (cadr (aref board pos))))
      (take-all (lazy-mapcar
		 (lambda (move)
		   (let ((path (car move)))
		     (if path
			 (let* ((src (car path))
				(dst (cadr path))
				(odds (aref (aref *dice-odds*
						  (1- (dice dst)))
					    (- (dice src) 2))))
			   (+ (* odds (rate-position (cadr move) player))
			      (* (- 1 odds) (rate-position (caddr move)
							   player))))
			 (rate-position (cadr move) player))))
		 (caddr tree))))))

(defun limit-tree-depth (tree depth)
  (list (car tree)
	(cadr tree)
	(if (zerop depth)
	    (lazy-nil)
	    (lazy-mapcar (lambda (move)
			   (cons (car move)
				 (mapcar (lambda (x)
					   (limit-tree-depth x (1- depth)))
					 (cdr move))))
			 (caddr tree)))))

(defun get-connected (board player pos)
  (labels ((check-pos (pos visited)
	     (if (and (eq (car (aref board pos)) player)
		      (not (member pos visited)))
		 (check-neighbors (neighbors pos) (cons pos visited))
		 visited))
	   (check-neighbors (lst visited)
	     (if lst
		 (check-neighbors (cdr lst) (check-pos (car lst) visited))
		 visited)))
    (check-pos pos '())))

(defun largest-cluster-size (board player)
  (labels ((f (pos visited best)
	     (if (< pos *board-hexnum*)
		 (if (and (eq (car (aref board pos)) player)
			  (not (member pos visited)))
		     (let* ((cluster (get-connected board player pos))
			    (size (length cluster)))
		       (if (> size best)
			   (f (1+ pos) (append cluster visited) size)
			   (f (1+ pos) (append cluster visited) best)))
		     (f (1+ pos) visited best))
		 best)))
    (f 0 '() 0)))

(defun add-new-dice (board player spare-dice)
  (declare (ignore spare-dice))
  (labels ((f (lst n)
	     (cond ((zerop n) lst)
		   ((null lst) nil)
		   (t (let ((cur-player (caar lst))
			    (cur-dice (cadar lst)))
			(if (and (eq cur-player player) (< cur-dice *max-dice*))
			    (cons (list cur-player (1+ cur-dice))
				  (f (cdr lst) (1- n)))
			    (cons (car lst) (f (cdr lst) n))))))))
    (board-array (f (coerce board 'list)
		    (largest-cluster-size board player)))))
