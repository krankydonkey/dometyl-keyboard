open! Base
open! Scad_ml

module Top = struct
  let clip_height = 1.1
end

module Bottom = struct
  let x = 17.15
  let y = 17.5
  let z = 4.
  let bulge_thickness = 0.5
  let bulge_length = 6.5
  let bulge_height = 3.2
  let ellipse_inset_x_rad = 1.4
  let circle_inset_y_scale = 1.2
  let corner_cut_rad = 5.
  let corner_cut_off = 2.75

  let ellipse =
    Model.scale (1., circle_inset_y_scale, 1.) (Model.circle ellipse_inset_x_rad)
    |> Model.translate (x /. 2., 0., 0.)

  let bulge =
    Model.cube (bulge_length, bulge_thickness +. 0.1, bulge_height)
    |> Model.translate (bulge_length /. -2., (y /. 2.) -. 0.1, 0.)

  let cutter =
    Model.circle corner_cut_rad
    |> Model.translate ((x /. 2.) +. corner_cut_off, (y /. 2.) +. corner_cut_off, 0.)

  let scad =
    Model.difference
      (Model.square ~center:true (x, y))
      [ ellipse
      ; Model.mirror (1, 0, 0) ellipse
      ; cutter
      ; Model.mirror (1, 0, 0) cutter
      ; Model.mirror (1, 1, 0) cutter
      ; Model.mirror (0, 1, 0) cutter
      ]
    |> Model.linear_extrude ~height:z
    |> fun b -> Model.union [ b; bulge; Model.mirror (0, 1, 0) bulge ]
end

let snap_slot_h = 1.2 (* TODO: better organization? *)

module HoleConfig : KeyHole.Config = struct
  (* TODO: Need to improve the way different switch types are handled, since the
   * presence of the platform clips in the side will mean that the joining of
   * columns etc will be different as well (clip holes not covered). To
   * accomplish this, may want to have another way of generating the faces that
   * are carried around with the KeyHole.t structs, so that they can be used
   * generically with the functions that join parts of columns to eachother. *)
  let outer_w = 19.5
  let inner_w = 14.
  let thickness = 4.

  let clip hole =
    let inset_depth = thickness -. Top.clip_height in
    let inset =
      Model.square ~center:true (Bottom.x, Bottom.y)
      |> Model.linear_extrude ~height:(inset_depth +. 0.01)
      |> Model.translate (0., 0., (thickness /. -2.) -. 0.01)
    in
    let bot =
      Model.translate (0., 0., (Bottom.z /. -2.) -. Top.clip_height) Bottom.scad
    in
    let snap =
      let w = Bottom.ellipse_inset_x_rad *. Bottom.circle_inset_y_scale *. 2. in
      let slot =
        Model.cube ~center:true (outer_w -. inner_w, w, snap_slot_h)
        |> Model.translate
             (outer_w /. 2., 0., ((thickness -. snap_slot_h) /. 2.) -. Top.clip_height)
      and ramp =
        let z = thickness -. Top.clip_height in
        Model.polygon [ 0., z /. -2.; snap_slot_h, z /. -2.; 0., z /. 2. ]
        |> Model.linear_extrude ~height:w
        |> Model.rotate (Math.pi /. 2., 0., 0.)
        |> Model.translate (Bottom.x /. 2., w /. 2., z /. -2.)
      in
      Model.union [ slot; ramp ]
    in
    Model.difference hole [ inset; bot; snap; Model.mirror (1, 0, 0) snap ]
end

module Sensor = struct
  let leg_w = 0.75
  let leg_thickness = 0.85 (* very exaggerated to account for print tolerances *)

  let leg_l = 20.
  let leg_spacing = 1.25
  let leg_bend = 4.
  let leg_z_offset = -0.2 (* from body centre *)

  let merge_legs = true

  (* let body_w = 4.
   * let body_l = 3. *)
  let body_w = 4.25
  let body_l = 3.25
  let thickness = 1.5

  let bent_leg =
    let start =
      Model.cube ~center:true (leg_w, leg_bend, leg_thickness)
      |> Model.translate (0., (leg_bend +. body_l) /. 2., 0.)
    and rest =
      Model.cube ~center:true (leg_w, leg_thickness, leg_l -. leg_bend)
      |> Model.translate
           ( 0.
           , leg_bend +. ((body_l -. leg_w) /. 2.)
           , (leg_l -. leg_bend -. leg_thickness) /. -2. )
    in
    Model.union [ start; rest ] |> Model.translate (0., 0., leg_z_offset)

  let legs =
    let side_offset = leg_spacing +. (leg_w /. 2.) in
    if not merge_legs
    then
      Model.union
        [ bent_leg
        ; Model.translate (-.side_offset, 0., 0.) bent_leg
        ; Model.translate (side_offset, 0., 0.) bent_leg
        ]
    else
      Model.union
        (Model.translate (side_offset, 0., 0.) bent_leg
         ::
         List.init
           ((Int.of_float (Float.round_down (leg_spacing *. 2. /. leg_w)) * 2) + 2)
           ~f:(fun i ->
             Model.translate
               ((Float.of_int i *. (leg_w /. 2.)) -. side_offset, 0., 0.)
               bent_leg ) )

  let body = Model.cube ~center:true (body_w, body_l, thickness)
  let scad = Model.union [ body; legs ] |> Model.translate (0., 0., thickness /. 2.)

  let sink depth =
    let f i = Model.translate (0., 0., Float.of_int i *. leg_thickness /. -2.) scad in
    List.init (Int.of_float (depth /. leg_w *. 2.) + 1) ~f
end

module Platform = struct
  (* let w = 21. *)
  let w = 20.
  let dome_w = 19.
  let dome_waist = 15. (* width at narrow point, ensure enough space at centre *)

  (* NOTE: BKE ~= 0.95mm; DES ~= 0.73mm. A value of 1.15 seems to fit both without
   * being too tight or loose on either. *)
  let dome_thickness = 1.15
  let base_thickness = 2.25
  let bottom_scale_factor = 1. (* downsize for tighter fit? *)

  let sensor_depth = 1.5

  let base =
    let slab =
      Model.cube ~center:true (w, w, base_thickness)
      |> Model.translate (0., 0., base_thickness /. -2.)
    in
    Model.difference slab (Sensor.sink sensor_depth)

  (* NOTE: Don't know why these config values on their own are resulting in a bit
   * of a gap between walls and plate. Possibly settle on a magic fudge value if the
   * issue persists / I don't find a better solution or the bug causing it. *)
  let wall_height =
    Bottom.z -. HoleConfig.thickness +. Top.clip_height +. dome_thickness +. 0.25

  let lug_height = 1.5

  let pillars =
    let waist_cut =
      let width = Bottom.ellipse_inset_x_rad *. Bottom.circle_inset_y_scale *. 2. in
      Model.polygon
        [ 0., 0.
        ; dome_waist, 0.
        ; dome_waist, dome_thickness
        ; dome_waist -. 0.5, dome_thickness +. 0.5
        ; 0.5, dome_thickness +. 0.5
        ; 0., dome_thickness
        ]
      |> Model.linear_extrude ~height:width
      |> Model.translate (dome_waist /. -2., 0., width /. -2.)
      |> Model.rotate (Math.pi /. 2., 0., 0.)
    in
    let cyl =
      Model.difference
        (Bottom.ellipse |> Model.linear_extrude ~height:wall_height)
        [ Model.cube
            ~center:true
            ( dome_waist
            , Bottom.ellipse_inset_x_rad *. Bottom.circle_inset_y_scale *. 2.
            , dome_thickness *. 2. )
        ]
    in
    Model.difference (Model.union [ cyl; Model.mirror (1, 0, 0) cyl ]) [ waist_cut ]

  let dome_cut =
    (* ensure overlap *)
    let fudged_w = dome_w +. 0.01 in
    Model.cube (fudged_w, fudged_w, dome_thickness)
    |> Model.translate (fudged_w /. -2., fudged_w /. -2., 0.)

  let ramp_cut =
    (* ~30 degrees *)
    let cut_l = 5.7 in
    let cut_h = 4. in
    let half_l = cut_l /. 2. in
    let half_h = cut_h /. 2. in
    let poly = Model.polygon [ 0., 0.; cut_h, 0.; cut_h, cut_l ] in
    let x_prism =
      Model.linear_extrude ~height:Bottom.x poly
      |> Model.translate (-.half_h, -.half_l, Bottom.x /. -2.)
      |> Model.rotate (Math.pi /. 2., Math.pi /. 2., Math.pi /. 2.)
      |> Model.translate (0., (dome_w /. 2.) -. half_l, half_h +. dome_thickness)
    in
    let y_prism =
      Model.difference
        ( Model.linear_extrude ~height:Bottom.y poly
        |> Model.translate (-.half_h, -.half_l, Bottom.y /. -2.)
        |> Model.rotate (Math.pi /. 2., Math.pi /. 2., 0.)
        |> Model.translate ((dome_w /. 2.) -. half_l, 0., half_h +. dome_thickness) )
        [ Model.scale (1., 1., 1.2) pillars ]
    in
    let corners =
      let block =
        Model.cube ~center:true (dome_w, cut_l, cut_h)
        |> Model.translate (0., (dome_w /. 2.) -. half_l, half_h +. dome_thickness)
      in
      let intersect =
        let x =
          Model.difference
            x_prism
            [ Model.translate (0., (Bottom.y -. dome_w) /. 2., 0.) block ]
          |> Model.translate ((dome_w -. Bottom.x) /. 2., 0., 0.)
        and y =
          Model.difference
            y_prism
            [ Model.rotate (0., 0., Math.pi /. -2.) block
              |> Model.translate ((Bottom.x -. dome_w) /. 2., 0., 0.)
            ]
          |> Model.translate (0., (dome_w -. Bottom.y) /. 2., 0.)
        in
        Model.intersection [ x; y ]
      in
      Model.union
        [ intersect
        ; Model.mirror (0, 1, 0) intersect
        ; Model.mirror (1, 0, 0) intersect
        ; Model.mirror (1, 0, 0) intersect |> Model.mirror (0, 1, 0)
        ]
    in
    Model.union
      [ x_prism
      ; Model.mirror (0, 1, 0) x_prism
      ; y_prism
      ; Model.mirror (1, 0, 0) y_prism
      ; corners
      ]

  let lugs =
    Model.difference
      (Model.cube ~center:true (Bottom.x -. 0.001, Bottom.y -. 0.001, lug_height))
      [ Model.translate (0., 0., -1.) Bottom.scad ]
    |> Model.translate (0., 0., (lug_height /. 2.) +. wall_height -. 0.001)

  let walls =
    let block =
      Model.union
        [ Model.cube ~center:true (w, w, wall_height +. 0.001)
          |> Model.translate (0., 0., wall_height /. 2.)
        ; lugs
        ]
    in
    Model.difference
      block
      [ Model.translate (0., 0., -0.001) Bottom.scad; dome_cut; ramp_cut ]

  let snap_heads =
    let clearance = 0.3 in
    let len = 0.7 (* was 0.8 in first success *)
    and width = 2. *. Bottom.ellipse_inset_x_rad *. Bottom.circle_inset_y_scale
    and z =
      wall_height
      +. HoleConfig.thickness
      -. Top.clip_height
      -. snap_slot_h
      +. (clearance /. 2.)
    in
    let tab =
      Model.cube (len, width, snap_slot_h -. clearance)
      |> Model.translate (Bottom.x /. 2., width /. -2., z)
    in
    let neck =
      Model.difference
        Bottom.ellipse
        [ Model.square (Bottom.ellipse_inset_x_rad, width)
          |> Model.translate (Bottom.x /. 2., width /. -2., 0.)
        ]
      |> Model.linear_extrude ~height:(z -. wall_height)
      |> Model.translate (0., 0., wall_height +. snap_slot_h -. clearance)
    in
    Model.union [ tab; Model.mirror (1, 0, 0) tab; neck; Model.mirror (1, 0, 0) neck ]

  let scad =
    Model.union [ base; Model.translate (0., 0., -0.001) walls; pillars; snap_heads ]

  (* let scad =
   *   Model.difference
   *     scad
   *     [ Model.translate (0., 20., 0.) (Model.cube ~center:true (30., 30., 20.))
   *     ; Model.translate (-20., 0., 0.) (Model.cube ~center:true (30., 30., 20.))
   *     ] *)
end