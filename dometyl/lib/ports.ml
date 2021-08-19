open! Base
open! Scad_ml

let make
    ?(length = 2.)
    ?(jack_radius = 2.65)
    ?(jack_width = 6.2)
    ?(usb_height = 3.6)
    ?(usb_width = 9.5)
    ?(board_width = 21.)
    ?(board_thickness = 2.)
    ?(dist = 15.5)
    ?(x_off = 6.)
    ?(z_off = 7.)
    Walls.{ body = { cols; _ }; _ }
  =
  let left_foot = (Option.value_exn (Map.find_exn cols 0).north).foot in
  let right_foot = (Option.value_exn (Map.find_exn cols 1).north).foot in
  let inner_y (foot : Points.t) =
    Vec3.(get_y foot.bot_left +. get_y foot.bot_right) /. 2.
  in
  let jack =
    Model.cylinder ~center:true ~fn:16 jack_radius 20.
    |> Model.rotate (Float.pi /. 2., 0., 0.)
  and usb =
    let rad = usb_height /. 2. in
    let cyl =
      Model.cylinder ~center:true ~fn:16 rad 20. |> Model.rotate (Float.pi /. 2., 0., 0.)
    in
    Model.hull
      [ Model.translate ((usb_width /. 2.) -. rad, 0., 0.) cyl
      ; Model.translate ((usb_width /. -2.) +. rad, 0., 0.) cyl
      ]
    |> Model.translate (dist, 0., 0.)
  and inset =
    let below = Float.max ((usb_height /. 2.) +. board_thickness) jack_radius in
    let h = jack_radius +. below
    and len (foot : Points.t) =
      (Vec3.(get_y foot.top_left +. get_y foot.top_right) /. 2.) -. inner_y foot
    in
    let left =
      let l = len left_foot in
      Model.cube ~center:true (jack_width, l, h)
      |> Model.translate
           (0., Float.max 0. (l -. length) -. (l /. 2.), (jack_radius -. below) /. 2.)
    in
    let right =
      let l = len right_foot
      (* bring right into frame of reference of left inner_y *)
      and y_diff = inner_y right_foot -. inner_y left_foot in
      Model.cube ~center:true (board_width, l, h)
      |> Model.translate
           ( dist
           , Float.max 0. (l -. length) -. (l /. 2.) +. y_diff
           , (jack_radius -. below) /. 2. )
    in
    Model.hull [ left; right ]
  in
  Model.union [ jack; usb; inset ]
  |> Model.translate Vec3.(get_x left_foot.bot_left +. x_off, inner_y left_foot, z_off)