(load "package://jsk_smart_gui/src/extra_actions.l")

(defun subscribe-tablet ()
  (ros::subscribe "/Tablet/Command"
		  jsk_gui_msgs::Tablet #'tablet-command-cb)

  (ros::subscribe "/Tablet/Task"
		  jsk_gui_msgs::Tablet #'tablet-task-cb)
  ;; for getting spot
  (ros::subscribe "/Tablet/GetSpot"
		  std_msgs::Empty #'tablet-getspot-cb)

  ;; TODO !!!!!!! speak translate !!!!!!!
  ;; (ros::subscribe "/Tablet/CommandDebug"
  ;; 		  jsk_gui_msgs::Tablet #'tablet-command-debug-cb)
  )

(defun tablet-getspot-cb(msg)
  (ros::ros-info "tablet-getspot-cb called")
  (make-temp-spots-cb))

(defun tablet-command-cb (msg)
  (if (is-old-msg msg) (return-from tablet-command-cb nil))
  (let* ((touches (send msg :touches))
	 ;; (x (send (car touches) :x)) (y (send (car touches) :y))
	 (taskname (read-from-string (send msg :action :task_name)))
	 (arm-id-raw (send msg :action :arm_id))
	 (arm-id (if (or (zerop arm-id-raw) (equal arm-id-raw jsk_gui_msgs::Action::*RARMID*)) ':rarm ':larm)))
;;    (ros::ros-debug "/Tablet/command: Received screenpoint ~A" (list x y))
    (case taskname
      ('MoveNeck
       (ros::ros-info "MoveNeck called")
       (MoveNeckExecute (send msg :action :direction) (send msg :action :direction_value)))
      ('MoveCameraCenter
       (ros::ros-info "MoveCameraCenter called")
       (MoveCameraCenterExecute (send msg :action :touch_x) (send msg :action :touch_y)))
      ('ZoomCamera
       (ros::ros-info "ZoomCamera called")
       (ZoomCameraExecute (send msg :action :touch_x) (send msg :action :touch_y) (send msg :action :state_value)))
      ('TorsoUp
       (ros::ros-info "TorsoUp called")
       (send *pr2* :torso :waist-z :joint-angle 325)
       (send *ri* :angle-vector (send *pr2* :angle-vector))
       ;; (send *ri* :wait-interpolation)
       )
      ('TorsoDown
       (ros::ros-info "TorsoDown called")
       (send *pr2* :torso :waist-z :joint-angle 50)
       (send *ri* :angle-vector (send *pr2* :angle-vector))
       ;; (send *ri* :wait-interpolation)
       )
      ('StopMotion
       (ros::ros-info "StopMotion called")
       (ros::spin-once)
       (send *pr2* :angle-vector (send *ri* :state :potentio-vector))
       (unix:usleep 100)
       (send *ri* :angle-vector (send *pr2* :angle-vector))
       (send *ri* :wait-interpolation))
      ('StopMotion
       (ros::ros-info "StopMotion called")
       (ros::spin-once)
       (send *pr2* :angle-vector (send *ri* :state :potentio-vector))
       (unix::usleep 100)
       (send *ri* :angle-vector (send *pr2* :angle-vector))
       (send *ri* :wait-interpolation))
      ('TuckArmPose
       (ros::ros-info "TuckArmPose called ~A" arm-id)
       (pr2-tuckarm-pose arm-id))
      ('OpenDoor
       (ros::ros-info "OpenDoor called")
       (if (null *chosen-ret*) (return-from tablet-command-cb nil))
       (print (list *chosen-ret* *range* ))
       (OpenDoorExecute arm-id *chosen-ret*))
      ('RotateGripper
       (ros::ros-info "RotateGripper called")
       (RotateGripper arm-id (send msg :action :state_value)))
      ('OpenGripper
       (ros::ros-info "OpenGripper called")
       (open-gripper arm-id))
      ('CloseGripper
       (ros::ros-info "CloseGripper called")
       (grasp-gripper arm-id))
      ('ResetAll
       (ros::ros-info "ResetAll called")
       (reset-all))

      ;;  ('give
      ;;  (ros::ros-info "give-cb")
      ;;  (hand-over hand))
      )))

;; this callback uses screenpoint-srvcall or point2pixel
(defun tablet-task-cb (msg)
  (if (or (is-old-msg msg) (check-ray-srv)) (return-from tablet-task-cb nil))
  (let* ((touches (send msg :touches))
	 (taskname (read-from-string (send msg :action :task_name)))
	 (arm-id-raw (send msg :action :arm_id))
	 (arm-id (if (or (zerop arm-id-raw) (equal arm-id-raw jsk_gui_msgs::Action::*RARMID*)) ':rarm ':larm))
	 tx ty c)
    (cond ((eq (length touches) 1)
	   (setq tx (send (car touches) :x) ty (send (car touches) :y))
	   (ros::ros-info "/Tablet/task: Sreenpoint = ~A" (list tx ty))
	   (if (null (setq c (screenpoint-srvcall tx ty)))
	       (return-from tablet-task-cb nil))
	   (ros::ros-info "/Tablet/task: Actual point = ~A" c))
	  (t
	   (ros::ros-info "/Tablet/task: touches >= 2")))
    (case taskname
      ('DrawLine
       (ros::ros-info "DrawLine called")
       ;; assumed that touches = 2
       (DrawLineExecute touches))
      ('OpenDoorInput
       (ros::ros-error "OpenDoorInput called")
       ;; assumed that touches = 3
       (OpenDoorInputExecute arm-id touches))
      ('MovingPointInfo
       (ros::ros-info "MovingPointInfoExecute called")
       ;; assumed that touches = 3
       (MovingPointInfoExecute touches))

      ;; ('pick
      ;;  (ros::ros-info "pick-cb")
      ;;  (pick-cb hand c))
      ;; ('slide2
      ;;  (ros::ros-info "slide-cb2")
      ;;  (slide-cb2 hand (send c :pos)))
      )))

;;       ('execute-slide2
;;        (ros::ros-info "execute-slide2")
;;        (if (null *chosen-ret*) (return-from execute-cb nil))
;;        (print (list *chosen-ret* *range* ))
;;        (execute-slide2 hand (send (elt *ret* *chosen-ret*) :worldpos))))

(defun DrawLineExecute (touches) ;; currently not drawing but setting points
  (unless (eq (length touches) 2)
    (ros::ros-warn "DrawLineExecute: ~A touches, returning" (length touches))
    (return-from DrawLineExecute nil))
  (dotimes (i 2) (setf (elt *line* i) (list (send (elt touches i) :x) (send (elt touches i) :y))))
  (ros::ros-info "DrawLineExecute: *line* = ~A" *line*)
  (let ((msg1 (instance geometry_msgs::PointStamped :init))
	(msg2 (instance geometry_msgs::PointStamped :init)) p0 p1)
    (visualize-line (elt *line* 0) (elt *line* 1)) ;; image_view2::ImageMarker2
    (send msg1 :point :x (elt (elt *line* 0) 0))
    (send msg1 :point :y (elt (elt *line* 0) 1))
    (send msg2 :point :x (elt (elt *line* 1) 0))
    (send msg2 :point :y (elt (elt *line* 1) 1))
    (setq p0 (point-srvcall msg1) p1 (point-srvcall msg2))
    (if (or (null p0) (null p1)) (return-from DrawLineExecute nil))
    (ros::ros-info "DrawLineExecute: point-srvcall succeed")
    (show-line (setf (elt *door* 0) (send p0 :worldpos))
	       (setf (elt *door* 1) (send p1 :worldpos))) ;; visualization_msgs::MarkerArray
    (setf (elt *drawer* 0) (send p0 :worldpos))
    (setf (elt *drawer* 1) (send p1 :worldpos))
    ))

(defun MovingPointInfoExecute (touches)
  ;; (if (and (and (null (elt *door* 0)) (null (elt *door* 1)))
  ;; 	   (< (length *opendoor*) 4)) (return-from MovingPointInfoExecute nil))
  (if (and (null (elt *door* 0)) (null (elt *door* 1)))
      (return-from MovingPointInfoExecute nil))
  (unless (boundp '*fp*) (return-from MovingPointInfoExecute nil))
  (unless (eq (length touches) 1)
    (ros::ros-warn "MovingPointInfoExecute: ~A touches, returning" (length touches))
    (return-from MovingPointInfoExecute nil))
  (let* ((tx (send (car touches) :x)) (ty (send (car touches) :y))
;;	 (c (screenpoint-srvcall tx ty))
	 (fi (list tx ty)))
    ;; (if (null c) (return-from MovingPointInfoExecute nil))
    ;;    (print c)
    (print fi)

    (visualize-line fi (point2pixel :px (aref *fp* 0) :py (aref *fp* 1) :pz (aref *fp* 2)))
    (setq *finger1* fi)
    (setq *chosen-ret* (position
			(apply #'min (mapcar #'(lambda (x) (distance (coerce *finger1* float-vector) (coerce x float-vector))) *ret2d*))
			(mapcar #'(lambda (x) (distance (coerce *finger1* float-vector) (coerce x float-vector))) *ret2d*)))
    (print (list *chosen-ret* *finger1* *ret2d*))
    ))

(defun MoveCameraCenterExecute (x y)
  (let (c)
    (send *pr2* :angle-vector (send *ri* :state :potentio-vector))
    (setq c (make-camera-from-ros-camera-info-aux 640 480 #f(892.302 0.0 422.326 0.0 0.0 892.302 268.051 0.0 0.0 0.0 1.0 0.0) (make-cascoords :pos (send *pr2* :wide_stereo-left :worldpos))))
    (send *pr2* :head :look-at (send (send (send *pr2* :wide_stereo-left :copy-worldcoords) :translate (scale 30000 (send c :ray x y))) :worldpos)) ;;TODO
    (send *ri* :angle-vector (send *pr2* :angle-vector) 500)))

(defun MoveNeckExecute (direction value)
  (send *pr2* :angle-vector (send *ri* :state :potentio-vector))
  (case (read-from-string direction)
    ('up
     (send *pr2* :head :neck-p :joint-angle (*  0.1 value) :relative t))
    ('down
     (send *pr2* :head :neck-p :joint-angle (* -0.1 value) :relative t))
    ('left
     (send *pr2* :head :neck-y :joint-angle (* -0.1 value) :relative t))
    ('right
     (send *pr2* :head :neck-y :joint-angle (*  0.1 value) :relative t))
    )
  (send *ri* :angle-vector (send *pr2* :angle-vector) 500))

(defun ZoomCameraExecute (mx my value);;
  (let* ((req (instance dynamic_reconfigure::ReconfigureRequest :init))
	 (width (floor (* pwidth (1+ (* value pmaxlength)))))
	 (height (floor (* pheight (1+ (* value pmaxlength)))))
	 (old_pwidth pwidth)(old_pheight pheight))
    (cond ((or (< width 640) (< height 480))
	   (setq pwidth 640 pheight 480)
	   (setq pbinning_x 1 pbinning_y 1))
	  ((or (> width 2432) (> height 1824))
	   (setq pwidth 2431 pheight 1823)
	   (setq pbinning_x 3 pbinning_y 3)
	   )
	  (t (setq pwidth width pheight height)
	     (setq pbinning_x 2 pbinning_y 2)
	     ))
    (ros::ros-info "ZoomCamera: width:~A, height:~A" pwidth pheight)
    (let ((x_offset (floor (+ px_offset (* mx (/ old_pwidth 640)) (/ pwidth -2))))
	  (y_offset (floor (+ py_offset (* my (/ old_pheight 640)) (/ pheight -2)))))
      (cond ((or (< x_offset 0) (< y_offset 0))
	     (setq px_offset 0 py_offset 0))
	    ((or (> x_offset 1792) (> y_offset 1344))
	     (setq px_offset 1792 py_offset 1344))
	    (t (setq px_offset x_offset py_offset y_offset)))
      (ros::ros-info "ZoomCamera: x_offset:~A, y_offset:~A" px_offset py_offset)
      (ros::ros-info "ZoomCamera: binning_x:~A, binning_y:~A" pbinning_x pbinning_y)
      (send req :config :ints
	    (list (instance dynamic_reconfigure::IntParameter
			    :init :name "binning_x" :value pbinning_x)
		  (instance dynamic_reconfigure::IntParameter
			    :init :name "binning_y" :value pbinning_y)
		  (instance dynamic_reconfigure::IntParameter
			    :init :name "x_offset" :value px_offset)
		  (instance dynamic_reconfigure::IntParameter
			    :init :name "y_offset" :value py_offset)
		  (instance dynamic_reconfigure::IntParameter
			    :init :name "width" :value pwidth)
		  (instance dynamic_reconfigure::IntParameter
			    :init :name "height" :value pheight)))
      (ros::service-call "prosilica_driver/set_parameters" req)
      (unix::usleep (* 500 1000))
      )))


