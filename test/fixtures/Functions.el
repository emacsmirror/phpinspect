(:root (:function (:declaration (:word "function") (:word "MergeTwoArraysAndSomeOtherStuff") (:list (:word "array") (:variable "array1") (:comma ",") (:variable "untyped_variable")) (:word "Response")) (:block (:variable "merged") (:assignment "=") (:word "array_merge") (:list (:variable "array_1") (:comma ",") (:variable "untyped_variable")) (:terminator ";") (:variable "mapped") (:assignment "=") (:word "arrap_map") (:list (:function (:declaration (:word "function") (:list (:variable "item"))) (:block (:word "return") (:variable "item") (:terminator ";"))) (:comma ",") (:variable "merged")) (:terminator ";") (:variable "user") (:assignment "=") (:variable "this") (:object-attrib (:word "user_repo")) (:object-attrib (:word "findOne")) (:list (:variable "req") (:object-attrib (:word "get")) (:list (:string "user"))) (:terminator ";") (:word "return") (:word "new") (:word "Response") (:list (:variable "this") (:object-attrib (:word "twig")) (:object-attrib (:word "render")) (:list (:string "address/create.html.twig") (:comma ",") (:array (:string "user") (:fat-arrow "=>") (:variable "user") (:comma ",")))) (:terminator ";"))) (:function (:declaration (:word "function") (:word "BeTheSecondFunctionInTheFile") (:list)) (:block (:word "return") (:array (:string "Very Impressive Result") (:fat-arrow "=>") (:variable "result")) (:terminator ";"))))
