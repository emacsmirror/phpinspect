; test-autoload.el --- Unit tests for phpinspect.el  -*- lexical-binding: t; -*-

(require 'ert)
(require 'phpinspect-pipeline)
(require 'phpinspect-resolve)
(require 'phpinspect-imports)
(require 'phpinspect)
(require 'phpinspect-test-env
         (expand-file-name "phpinspect-test-env.el"
                           (file-name-directory (macroexp-file-name))))

(defun phpinspect--make-dummy-composer-project ()
  (let ((fs (phpinspect-make-virtual-fs)))
    (phpinspect-virtual-fs-set-file
      fs
      "/project/root/composer.json"
      "{ \"autoload\": { \"psr-4\": {\"App\\\\\": [\"src/\", \"lib\"]}}}")

    (phpinspect-virtual-fs-set-file fs "/project/root/src/Foo.php" "")
    (phpinspect-virtual-fs-set-file fs "/project/root/src/Bar.php" "")

    (let* ((project (phpinspect--make-dummy-project fs "/project/root"))
           (autoload (phpinspect-project-autoload project))
           result error)

      (phpinspect-autoloader-refresh autoload (lambda (res err)
                                                (setq result res error err)))

      (while (not (or result error))
        (thread-yield))

      project)))

(ert-deftest phpinspect-fix-imports-single-namespaced-class ()
  (let ((project (phpinspect--make-dummy-composer-project)))
    (with-temp-buffer
      (let* ((buffer (phpinspect-make-buffer :buffer (current-buffer)
                                             :-project project)))

        (insert "<php

namespace Not\\App;

class Baz {
    private Foo $foo;
    public Bar $bar;
}")
        ;; Ensure buffer is made aware of changes
        (setq phpinspect-current-buffer buffer)
        (add-hook 'after-change-functions #'phpinspect-after-change-function)

        (phpinspect-fix-imports)
        (should (string= "<php

namespace Not\\App;

use App\\Bar;
use App\\Foo;


class Baz {
    private Foo $foo;
    public Bar $bar;
}"
                         (buffer-string)))))))
