;;; Cross-platform LispPadCore prelude
;;;
;;; Keeps the first shared runtime lightweight by avoiding platform-specific
;;; LispPad system libraries while still shaping the initial REPL environment.

(import (lispkit base))

;;; Keep LispKit's native random procedures intact.
;;; SCMUtils relies on `(random n)` yielding an integer when `n` is exact.
