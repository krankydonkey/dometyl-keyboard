open OCADml
open OSCADml
open! Dometyl

(* NOTE: The curvature of this configuration is made with MT3 caps in mind.
   As SA caps are taller, they will likely be in collision with one another, as
   can be seen if you set `Plate.make ~caps:Caps.SA.row`. The inner index Matty3
   key models appear to collide here, but cases printed with this config do make
   room for real MT3 caps. *)
let body_lookups =
  let offset = function
    | 2 -> v3 0. 3.5 (-5.) (* middle *)
    | 3 -> v3 1. (-2.5) 0.5 (* ring *)
    | i when i >= 4 -> v3 0.5 (-18.) 8.5 (* pinky *)
    | 0 -> v3 (-2.5) 0. 5.
    | _ -> v3 0. 0. 0.
  and curve = function
    | i when i >= 3 ->
      (* ring and pinky *)
      Curvature.(curve ~well:(well ~radius:37. (Float.pi /. 4.25)) ())
    | i when i = 0 ->
      Curvature.(
        curve ~well:(well ~tilt:(Float.pi /. 7.5) ~radius:46. (Float.pi /. 5.95)) () )
    | _ -> Curvature.(curve ~well:(well ~radius:46.5 (Float.pi /. 6.1)) ())
  and splay = function
    | i when i = 3 -> Float.pi /. -25. (* ring *)
    | i when i >= 4 -> Float.pi /. -22. (* pinky *)
    | _ -> 0.
  and rows _ = 3 in
  Plate.Lookups.body ~offset ~curve ~splay ~rows ()

let thumb_lookups =
  let curve _ =
    Curvature.(
      curve
        ~fan:(fan ~radius:70. ~tilt:(Float.pi /. 48.) (Float.pi /. 9.))
        ~well:(well ~radius:47. (Float.pi /. 6.))
        () )
  in
  Plate.Lookups.thumb ~curve ()

let plate_builder =
  Plate.make
    ~n_body_cols:5
    ~body_lookups
    ~thumb_lookups
    ~thumb_offset:(v3 (5.) (-47.) (-3.))
    ~thumb_angle:Float.(v3 (pi /. 30.) (pi /. -4.) (pi /. 24.))
    ~rotate_thumb_clips:false
    ~caps:Caps.DSA.uniform
    ~thumb_caps:Caps.DSA.uniform

let wall_builder plate =
  Walls.
    { body =
        auto_body
          ~d1:(`Abs 14.)
          ~d2:10.
          ~n_steps:(`PerZ 0.5)
          ~scale:(v2 0.8 0.9)
          ~scale_ez:(v2 0.42 1., v2 1. 1.)
          plate
    ; thumb =
        auto_thumb
          ~d1:(`Abs 14.)
          ~d2:8.
          ~n_steps:(`PerZ 0.5)
          ~north_lookup:(fun _ -> false)
          ~south_lookup:(fun i -> i <> 1)
          ~east_lookup:(fun _ -> false)
          ~west_lookup:(fun _ -> true)
          ~scale:(v2 0.8 0.9)
          ~scale_ez:(v2 0.42 1., v2 1. 1.)
          plate
    }

let base_connector =
  Connect.skeleton
    ~height:13.
    ~index_height:16.
    ~thumb_height:14.
    ~corner_fn:3
    ~close_thumb:false
    ~north_joins:(fun i -> i < 2)
    ~south_joins:(Fun.const false)

let plate_welder plate =
  Scad.union [ Plate.skeleton_bridges plate; Bridge.cols ~columns:plate.body 1 2 ]

let ports_cutter = BastardShield.(cutter ~x_off:0. ~y_off:0.5 (make ()))

let build ?right_hand ?hotswap () =
  (* let eyelets = Case.eyelets ~config:Eyelet.magnet_6x3_config () in *)
  let eyelets = Case.eyelets ~config:Eyelet.m4_config () in
  Case.make
    ?right_hand
    ~eyelets
    ~plate_builder
    ~plate_welder
    ~wall_builder
    ~base_connector
    ~ports_cutter
    (Mx.make_hole ?hotswap ~clearance:2. ~fn:3 ())

let thin_mag = Eyelet.Magnet { rad = 2.65; thickness = 1.2 }

let bottom ?fastener case =
  (*  For a thinner plate with 5x1 magnets, try providing [~fastener:thin_mag]
    (assuming you are using bigger magnets as the [~eyelets] for the case above). If
   [~fastener] is not specified, [Bottom.make] will default to the same magnet
    used for the case. *)
  let bump_locs =
    Bottom.
      [ thumb ~loc:(v2 0.5 0.2) Last First
      ; thumb ~loc:(v2 0.7 0.) Last Last
      ; body ~loc:(v2 0. 1.2) First Last (* top index *)
      ; body ~loc:(v2 0.5 1.3) (Idx 3) Last (* top ring *)
      ; body ~loc:(v2 0.9 0.8) Last Last (* top pinky *)
      ; body ~loc:(v2 0.7 (-0.3)) Last First (* bottom pinky *)
      ]
  in
  Bottom.make ?fastener ~bump_locs case

let tent case = Tent.make ~degrees:30. case