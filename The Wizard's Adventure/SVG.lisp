(defmacro split (val yes no)
  (let ((g (gensym)))
    `(let ((,g ,val))
       (if ,g
	   (let ((head (car ,g))
		 (tail (cdr ,g)))
	     ,yes)
	   ,no))))

(defun pairs (lst)
  (labels ((f (lst acc)
	     (split lst
		    (if tail
			(f (cdr tail) (cons (cons head (car tail)) acc))
			(reverse acc))
		    (reverse acc))))
    (f lst nil)))

(defun print-tag (name alst closingp)
    (princ #\<)
  (when closingp
    (princ #\/))
  (princ (string-downcase name))
  (mapc (lambda (att)
	  (format t " ~a=\"~a\"" (string-downcase (car att)) (cdr att)))
	alst)
  (princ #\>))

(defmacro tag (name atts &body body)
  `(progn (print-tag ',name
		     (list ,@(mapcar (lambda (x)
				       `(cons ',(car x) ,(cdr x)))
				     (pairs atts)))
		     nil)
	  ,@body
	  (print-tag ',name nil t)))

(defmacro svg (&body body)
  `(tag svg (xmlns "https://www.w3.org/2000/svg"
		   "xmlns:xlink" "https://www.w3.org/1999/xlink")
	,@body))

(defun brightness (col amt)
  (mapcar (lambda (x)
	    (min 255 (max 0 (+ x amt))))
	  col))

(defun svg-style (color)
  (format nil
	  "~{fill:rgb(~a,~a,~a);stroke:rgb(~a,~a,~a)~}"
	  (append color
		  (brightness color -100))))

(defun circle (center radius color)
  (tag circle (cx (car center)
		  cy (cdr center)
		  r radius
		  style (svg-style color))))

(defun polygon (points color)
  (tag polygon (points (format nil
			       "~{~a, ~a ~}"
			       (mapcan (lambda (tp)
					 (list (car tp) (cdr tp)))
				       points))
		       style (svg-style color))))

;; Before Tail Call Optimazation
(defun random-walk (value length)
  (unless (zerop length)
    (cons value
	  (random-walk (if (zerop (random 2))
			   (1- value)
			   (1+ value))
		       (1- length)))))

;; After Tail Call Optimazation
(defun random-walk (value length)
  (labels ((random-walk-aux (value length)
             (if (zerop length)
		 nil
                 (cons value
		       (random-walk-aux (if (zerop (random 2))
					   (1- value)
					   (1+ value))
				       (1- length))))))
    (random-walk-aux value length)))

(defun make-graph ()
  (with-open-file (*standard-output* "random_walk.svg"
				    :direction :output
				    :if-exists :supersede)
  (svg (loop repeat 10
	     do (polygon (append '((0 . 200))
				 (loop for x from 1
				       for y in (random-walk 100 400)
				       collect (cons x y))
				 '((400 . 200)))
			 (loop repeat 3
			       collect (random 256)))))))
