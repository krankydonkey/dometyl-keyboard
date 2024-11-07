open! OCADml
open OSCADml
open! Dometyl
open! Examples

(* It is recommended to use the "<include> trick" for models produced by dometyl
    for OpenSCAD editor related performance reasons. This will generate an
    additional file prefixed with "incl_" that contains the actual model, while
    the script with the given base name simply <include>'s it. *)
let to_file = Scad.to_file ~incl:true

(* NOTE: If you aren't using hotswap holders, you can simply mirror the generated case stl,
   but if you are, you will need to make a left-hand case like so. The bottom plate and
   tenting base will of course still be reversible, so you can mirror those in your slicer
   as you would a case with plain switch holes. Though you can also make bottoms/tent for
   left cases directly here as well. *)

let dvk_right = Dvk.build ~hotswap:`South ()
let dvk_left = Dvk.build ~hotswap:`South ~right_hand:false ()

let () =
  to_file "dvk_right.scad" (Case.to_scad ~show_caps:false dvk_right);
  to_file "dvk_left.scad" (Case.to_scad dvk_left);
  to_file "dvk_bottom_plate_right.scad" (Dvk.bottom @@ dvk_right);
  to_file "dvk_tent_right.scad" (Tent.make dvk_right)
