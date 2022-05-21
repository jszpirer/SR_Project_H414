-- Use Shift + Click to select a robot
-- When a robot is selected, its variables appear in this editor

-- Use Ctrl + Click (Cmd + Click on Mac) to move a selected robot to a different location

-- These variables are part of the special logic that enables multi-robot opeation - do not alter this part!
-- is_typerobot: a shorthand reference to know the robot type
is_cambot    = false
is_groundbot = false
is_lightbot  = false


-- Put your global variables here, after this line
avoid_obstacle = false
number_robot_sensed = 0
STOP = false


-- Variables for cam robot
looking_for_object = true
object_gripped = false
object_to_grip = false
looking_for_grdbot = false
obstacle_found = false
unlocking_object = false
check_if_in_nest = false
obstacle_counter = 0
angle_grdbot = 0.0
steps_to_walk = 0
nest_angle = 0
nest_range = 0
nest_index = 1
wait_steps = 0
GRIP_COUNTER = 0
MAX_GRIPPED = 700
TARGET_DIST = 70
EPSILON = 30
WHEEL_SPEED = 8
DROPPING_TIMEOUT = 50 -- adapt this value to drop faster (with potentially unsuccessful unlocks)
dropping_timer = 0
dropping_angle = 0

ACCEPT_DIST = 10
FLOCKING_TRIGGER_THRESHOLD = 30
NEIGHBORS_AT_TARG_DIST = 6
FLOCKING_TRIGGER_COUNTER = 0
FLOCKING_CONDITION = 0
FLOCKING = 0

-- Variables for lightbots
looking_for_light = true


-- Variables for groundbots
looking_for_nest = true
walking_around_nest = false
avoiding_obstacle = false
walk_counter = 0



--[[ Control function function for the CamBot robots. ]]
function cambot_control()
 	-- Insert your code here, after this line
	-- This robot will be in the middle of the line
	robot.range_and_bearing.set_data(3, 0)
	if (looking_for_object) then
		index_of_blob = 1
		best_distance = 1000
		object_found = false 
		robot.colored_blob_omnidirectional_camera.enable()
		--log("Number of blobs" .. #robot.colored_blob_omnidirectional_camera)
		for i=1, #robot.colored_blob_omnidirectional_camera do
			if robot.colored_blob_omnidirectional_camera[i].color.red == 255.0 then
				if robot.colored_blob_omnidirectional_camera[i].color.blue == 0.0 then
					distance = robot.colored_blob_omnidirectional_camera[i].distance
					if (distance < best_distance) then
						best_distance = distance
						index_of_blob = i
						object_found = true
					end
					if (best_distance < 20) then
						STOP = true
						object_found = true
						break
					end
				end
			end
		end
		for i = 1, #robot.range_and_bearing do
			if robot.range_and_bearing[i].data[1] == 3 then
				speeds = ComputeSpeedFromAngle(math.pi)
				robot.wheels.set_velocity(speeds[1], speeds[2])
			end
		end
		tube_is_transported = is_tube_transported()
		if (tube_is_transported) then
			object_found = false
			STOP = false
		end
		if (object_found) then
			if (STOP) then
				speeds_cyl = ComputeSpeedFromAngle(robot.colored_blob_omnidirectional_camera[index_of_blob].angle)
				robot.wheels.set_velocity(speeds_cyl[1], speeds_cyl[2])
				init_drop_procedure()
				object_to_grip = true
				object_found = false
				looking_for_object = false
			else
				--log("Closer")
				-- On se dirige vers l'objet le plus proche (distance)
				angle = robot.colored_blob_omnidirectional_camera[index_of_blob].angle
				if (angle < 3.14) and (angle > 0) then
					--log ("Direction tubes")
					robot.wheels.set_velocity(10, 20)
				else
					--log ("Direction tubes")
					robot.wheels.set_velocity(20, 10)
				end
			end
		else
			--log("Random walk")
			random_walk(20)
		end 
	
	elseif (obstacle_found) then
		obstacle_counter = obstacle_counter - 1
		if (obstacle_counter == 0) then
			obstacle_found = false
			beginning_flocking = true
		else
			robot.wheels.set_velocity(speeds_obstacle[1], speeds_obstacle[2])
		end




	-- Next section is about gripping the object and transport it
	elseif (object_to_grip) then
		--log("Tube gripped")
		lock_object()
		--robot.gripper.lock_positive()
		--robot.gripper.lock_negative()
		--object_to_grip = false
		--object_gripped = true
		--GRIP_COUNTER = 0
		--robot.range_and_bearing.set_data(1, 4)
		--turn_around = true
	

	-- Need to turn around and go to the nest
	elseif (turn_around) then
		log("Turn around")
		speeds = ComputeSpeedFromAngle(math.pi)
		robot.wheels.set_velocity(speeds[1], speeds[2])
		looking_for_lightbot = true
		turn_around = false


	elseif (looking_for_lightbot) then
		if (object_gripped) then
			GRIP_COUNTER = GRIP_COUNTER +1
		end
		--log("Looking for light bots")
		random_walk(20)
		for i = 1, #robot.colored_blob_omnidirectional_camera do
			if robot.colored_blob_omnidirectional_camera[i].color.red == 255.0 then
				if robot.colored_blob_omnidirectional_camera[i].color.blue == 0.0 then
					-- A red tube has been viewed
					if (not object_gripped) then
						looking_for_lightbot = false
						looking_for_object = true
						break
					end
				end
			end
		end
		for i = 1, #robot.range_and_bearing do
			log("Signal reçu".. robot.range_and_bearing[i].data[1])
			if robot.range_and_bearing[i].data[4] == 4 then
				if (object_gripped) then
					lightbot_found = true
				else
					looking_for_object = true
				end
				looking_for_lightbot = false
				log("Lightbot found")
			elseif robot.range_and_bearing[i].data[1] == 3 then
				-- Groundbot found, could be good is the object is gripped
				if (object_gripped) then
					looking_for_grdbot = true
					looking_for_lightbot = false
				end
			end
		end
		if (tube_in_nest()) then
			logerr("Arrivé dans le nid plus tôt")
			looking_for_lightbot = false
			steps_to_walk = robot.random.uniform_int(8,25)
			road_to_nest = true
		elseif (GRIP_COUNTER > MAX_GRIPPED) then
			log("Transport trop long")
			looking_for_lightbot = false
			init_drop_procedure()
			unlocking_object = true
		end
			
	elseif (lightbot_found) then
		for i = 1, #robot.range_and_bearing do
			if robot.range_and_bearing[i].data[4] == 4 then
				random_walk(30)
			else
				random_walk(20)
				lightbot_found = false
				looking_for_grdbot = true
			break
			end
		end


	elseif (looking_for_grdbot) then
		GRIP_COUNTER = GRIP_COUNTER +1
		for i = 1, #robot.range_and_bearing do
			if robot.range_and_bearing[i].data[1] == 3 then
				log("GrdBot found" .. robot.range_and_bearing[i].data[1])
				grdbot_found = true
				looking_for_grdbot = false
				angle_grdbot = robot.range_and_bearing[i].horizontal_bearing
				log("L'angle est "..angle_grdbot)
				nest_index = i
				break
			end
		end
		if (grdbot_found) then
			robot.wheels.set_velocity(0,0)
		else
			random_walk(20)
		end
		if (tube_in_nest()) then
			logerr("Arrivé dans le nid plus tôt")
			looking_for_grdbot = false
			steps_to_walk = robot.random.uniform_int(8,25)
			road_to_nest = true
		elseif (GRIP_COUNTER > MAX_GRIPPED) then
			log("Transport trop long")
			looking_for_grdbot = false
			init_drop_procedure()
			unlocking_object = true
		end
		
	
	
	elseif (grdbot_found) then
		ground_bots = false
		for i = 1, #robot.range_and_bearing do
			if robot.range_and_bearing[i].data[1] == 3 then
				ground_bots = true
				angle = robot.range_and_bearing[i].horizontal_bearing
				log("Angle avec ground".. angle)
				if (angle > 1.22 and math.pi/2 >= angle) then
					steps_to_walk = 25
					grdbot_found = false
					road_to_nest = true
					break
				elseif (-1.22 > angle and angle > -math.pi/2) then
					steps_to_walk = 25
					grdbot_found = false
					road_to_nest = true
					break
				else 
					random_walk(30)
				end
			end
		end
		if (tube_in_nest()) then
			logerr("Arrivé dans le nid plus tôt")
			grdbot_found = false
			steps_to_walk = robot.random.uniform_int(8,25)
			road_to_nest = true
		elseif (not ground_bots) then
			-- The cambot is not seeing any ground bot anymore
			grdbot_found = false	
			looking_for_grdbot = true
		end
		--if (robot.range_and_bearing[nest_index] ~= nil) then
			--new_angle = robot.range_and_bearing[nest_index].horizontal_bearing
			--distance = robot.range_and_bearing[nest_index].range
			--log("Angle ".. new_angle)
			--if new_angle > angle_grdbot then
				-- Ground bot de l'autre côté du nid			
				--steps_to_walk = 90
			--else 
				--steps_to_walk = 40
			--end
			--log("Steps to wait")
			--grdbot_found = false
			--robot.wheels.set_velocity(0,0)
			--nest_angle = new_angle
			--nest_range = robot.range_and_bearing[nest_index].range
			--road_to_nest = true
		--end


	elseif (road_to_nest) then
		steps_to_walk = steps_to_walk - 1
		log("Steps ".. steps_to_walk) 
		if steps_to_walk < 0 then
			--log("Temps de réfléchir")
			--if (#robot.colored_blob_omnidirectional_camera > 2) then
				check_if_in_nest = true
				--init_drop_procedure()
				--unlocking_object = true
				road_to_nest = false
				wait_steps = 30
			--else
				--road_to_nest = false
				--looking_for_grdbot = true
			--end
		else
			random_walk(20)
			--speeds_angle = ComputeSpeedFromAngle(nest_angle)
			--robot.wheels.set_velocity(speeds_angle[1]+10, speeds_angle[2]+10)
		end
	elseif (check_if_in_nest) then
		--robot.range_and_bearing.set_data(3, 3)
		wait_steps = wait_steps - 1
		if (wait_steps == 0) then
			logerr("Attente finie")
			if tube_in_nest() then
				logerr("In the nest")
				check_if_in_nest = false
				init_drop_procedure()
				unlocking_object = true
			else
				logerr("Not in nest")
				looking_for_grdbot = true
				check_if_in_nest = false
			end
		--if wait_steps < 5 then 
			--for i = 1, #robot.range_and_bearing do
				--log("Signal reçu 2".. robot.range_and_bearing[i].data[2])
				--if robot.range_and_bearing[i].data[2] == 2 then
					-- Sure we are in the nest?
					--log("In the nest")
					--check_if_in_nest = false
					--init_drop_procedure()
					--unlocking_object = true
				--else
					--if (wait_steps == 0) then
						--looking_for_grdbot = true
						--check_if_in_nest = false
					--end				
				--end
			--end
		else 
			robot.wheels.set_velocity(0,0)
		end

	elseif (unlocking_object) then
		log("Unlocking")
		--angle_tube = nearest_obstacle_angle()
		--speeds = ComputeSpeedFromAngle(angle_tube)
		--robot.wheels.set_velocity(speeds[1], speeds[2])
		--robot.gripper.unlock()
		drop_object()

	else
		random_walk(20)			
	
	end
	--robot.range_and_bearing.clear_data()
end
 
 --[[ Control function function for the GroundBot robots. ]]
function groundbot_control()
     -- Insert your code here, after this line
	-- They need to be looking for the nest
	if (looking_for_nest) then
		--log("Looking for nest")
		nest_found = false
		for i=1, 4 do
			value = robot.motor_ground[i].value
			if (value == 0) then
				--log("Nest found")
				nest_found = true
				looking_for_nest = false
				walking_around_nest = true
			end
		end
		if (nest_found) then
			robot.wheels.set_velocity(0, 0)
		else
			random_walk(20)
		end

	-- The robot is walking around the nest to determine the size of it.
	elseif (walking_around_nest) then
		--log("Walking around nest")
		-- On check si y'a un robot dans le nid
		cambot_viewed = false
		--for i = 1, #robot.range_and_bearing do
			--log("Je vois "..robot.range_and_bearing[i].data[3])
			 --if robot.range_and_bearing[i].data[3] == 3 then
				-- Need to check the angle of the cambot that is waiting in the nest
				--angle = robot.range_and_bearing[i].horizontal_bearing
				--if (angle > 0) then
					--log("Cambot in nest")
					--cambot_viewed = true
					--robot.range_and_bearing.set_data(2, 2)
				--end
			--end
		--end
		--if (not cambot_viewed) then
			--robot.range_and_bearing.set_data(2, 3)
		--end
		robot.range_and_bearing.set_data(1, 3)
		vect = {fl=1, bl=1, br=1, fr=1}
		vect.fl = robot.motor_ground[1].value
		vect.bl = robot.motor_ground[2].value
		vect.br = robot.motor_ground[3].value
		vect.fr = robot.motor_ground[4].value
		if (vect.fl == 0) and (vect.bl == 0) and (vect.br == 1) and (vect.fr == 1) then
			robot.wheels.set_velocity(5, 5)
		elseif (vect.fl == 1) and (vect.bl == 1) and (vect.br == 1) and (vect.fr == 1) then
			walking_around_nest = false
			looking_for_nest = true
		elseif (vect.fl == 1) then
			if (vect.fr == 0) then
				robot.wheels.set_velocity(5, -5)
			else
				robot.wheels.set_velocity(-5, 5)
			end
		elseif (vect.bl == 1) then
			robot.wheels.set_velocity(10, 5)
		else
			robot.wheels.set_velocity(5, 10)
		end
		obstacle = false
		for i=1,4 do
			if (robot.proximity[i].value > 0.5) then
				obstacle = true
				avoiding_obstacle = true
				walk_counter = 30
				walking_around_nest = false
				break
			end
		end
		if (not obstacle) then
			for i=20,24 do
				if (robot.proximity[i].value > 0.5) then
					avoiding_obstacle = true
					walk_counter = 30
					walking_around_nest = false
					break
				end			
			end
		end
	
	elseif (avoiding_obstacle) then
		walk_counter = walk_counter - 1
		if (walk_counter < 0) then
			avoiding_obstacle = false
			looking_for_nest = true
		else
			--robot.wheels.set_velocity(0,0)
			random_walk(2)
		end
	end
	--robot.range_and_bearing.clear_data()
end
  
  --[[ Control function function for the LightBot robots. ]]
function lightbot_control()
     -- Insert your code here, after this line
	robot.range_and_bearing.set_data(4, 4)
	if (looking_for_light) then
		--log("Looking for light")
		light_found = false
		best_value = 0
		index = 1
		for i=1, 24 do
			value_light = robot.light[i].value
			if (value_light > best_value) then
					--log("Light found")
					best_value = value_light
					index = i
					light_found = true
			end
			if (best_value == 1) then
				STOP = true
				light_found = true
				looking_for_light = false
			end
		end
		--log("For done")
		if (light_found) then
			if (STOP) then
				--log("Light stopped")
				robot.wheels.set_velocity(0, 0)
			else
				-- Need to analyze the position of the light to adjust the velocity
				if (index < 4) or (index > 21) then
					robot.wheels.set_velocity(10, 10)
				elseif (index < 10) then
					robot.wheels.set_velocity(5, 10)
				elseif (index < 16) then
					robot.wheels.set_velocity(-10, -10)
				else
					robot.wheels.set_velocity(10, 5)
				end
			end
		else
			--log("Light Random walk")			
			random_walk(20)
		end
	end
end


--[[ This function checks if the robot type, based on its ID. 
     It should be called from init and reset, but not from step ]]
function check_robot_type()
    -- special logic to enable multi-robot opeation - do not alter this part!
    if string.find(robot.id, "cam") ~= nil then
        is_cambot    = true
        is_groundbot = false
        is_lightbot  = false
        led_color = "yellow"
    end

    if string.find(robot.id, "gnd") ~= nil then
        is_cambot    = false
        is_groundbot = true
        is_lightbot  = false
        led_color = "cyan"
    end

    if string.find(robot.id, "lgt") ~= nil then
        is_cambot    = false
        is_groundbot = false
        is_lightbot  = true
        led_color = "magenta"
    end

    -- this line is to help you with visualizing the roles in the swarm
    -- comment or remove this line before performing your experiments
    --robot.leds.set_all_colors(led_color)
   
end

--[[ This function is executed every time you press the 'execute' button ]]
function init()
   -- special logic to enable multi-robot opeation - do not alter this part!
   check_robot_type()

   -- put your code here, after this line
	looking_for_light = true
end

--[[ This function is executed at each time step
     It will execute the logic of the controller for each
     type of robot ]]
function step()
	robot.range_and_bearing.set_data(1,5)
   -- special logic to enable multi-robot opeation - do not alter this part!
   if is_cambot then
        cambot_control()
   end
   if is_groundbot then
       groundbot_control()
   end
   if is_lightbot then
        lightbot_control()
   end
   -- If no robot type is found, nothing will happen
end

function random_walk(speed)
	-- SENSE
	obstacle = false
	index = 0
	for i=1,4 do
		if (robot.proximity[i].value > 0.2) then
			obstacle = true
			index = i
			break
		end
	end
	if (not obstacle) then
		for i=20,24 do
			if (robot.proximity[i].value > 0.2) then
				obstacle = true
				index = i
				break
			end			
		end
	end

	-- THINK	
	if(not avoid_obstacle) then
		if(obstacle) then
			avoid_obstacle = true
			turning_steps = robot.random.uniform_int(3,8)
			--turning_steps = 4
			--if (index < 20) then
				--turning_right = 1
			--else 
				--turning_right = 0
			--end
			turning_right = robot.random.bernoulli()
		end
	else
		turning_steps = turning_steps - 1
		if(turning_steps == 0) then 
			avoid_obstacle = false
		end
	end

	-- ACT
	if(not avoid_obstacle) then
		robot.wheels.set_velocity(speed,speed)
	else
		if(turning_right == 1) then
			robot.wheels.set_velocity(speed,-speed)
		else
			robot.wheels.set_velocity(-speed,speed)
		end
	end
	
end

function count_voisins()
	number_robot_sensed = 0
	for i = 1, #robot.range_and_bearing do 
		if robot.range_and_bearing[i].range < 150 and robot.range_and_bearing[i].data[1]==1 then
			number_robot_sensed = number_robot_sensed + 1
		end
	end
	if (number_robot_sensed == 2) then
		two_voisins = true
	end
end

function ProcessRAB_LJ()
	FLOCKING_CONDITION = 0
	sum_vector = {0,0}
	neighbors_in_range_counter = 0
	for i = 1, #robot.range_and_bearing do
		if (robot.range_and_bearing[i].data[1] == 1) then -- Just the cambots
			lj_value = ComputeLennardJones(robot.range_and_bearing[i].range)
			sum_vector[1] = sum_vector[1] + math.cos(robot.range_and_bearing[i].horizontal_bearing)*lj_value
			sum_vector[2] = sum_vector[2] + math.sin(robot.range_and_bearing[i].horizontal_bearing)*lj_value
			if(robot.range_and_bearing[i].range < TARGET_DIST + ACCEPT_DIST and robot.range_and_bearing[i].range > TARGET_DIST - ACCEPT_DIST) then
				neighbors_in_range_counter = neighbors_in_range_counter + 1
				if (neighbors_in_range_counter >= NEIGHBORS_AT_TARG_DIST) then
					FLOCKING_CONDITION = 1
				end
			end
		end
	end
	return sum_vector
end

function ComputeLennardJones(distance) 
	return -(4*EPSILON/distance * (math.pow(TARGET_DIST/distance,4) - math.pow(TARGET_DIST/distance,2)));
end

function ComputeVectorToTubes()
	tube_v = {0,0}
	index_of_blob = 1
	best_distance = 1000
	object_found = false 
	robot.colored_blob_omnidirectional_camera.enable()
	for i=1, #robot.colored_blob_omnidirectional_camera do
		if robot.colored_blob_omnidirectional_camera[i].color.red == 255.0 then
			if robot.colored_blob_omnidirectional_camera[i].color.blue == 0.0 then
				distance = robot.colored_blob_omnidirectional_camera[i].distance
				if (distance < best_distance) then
					best_distance = distance
					index_of_blob = i
					object_found = true
				end
				if (best_distance < 20) then
					log("Tube is here")
					STOP = true
					object_found = true
					break
				end
			end
		end
	end
	if (object_found) then -- We can compute the real vector to tube
		tube_v[1] = best_distance * math.cos(robot.colored_blob_omnidirectional_camera[index_of_blob].angle)
		tube_v[2] = best_distance * math.sin(robot.colored_blob_omnidirectional_camera[index_of_blob].angle)
		len = math.sqrt(tube_v[1] * tube_v[1] + tube_v[2] * tube_v[2])
		if (len ~= 0) then
			tube_v[1] = tube_v[1] / len
			tube_v[2] = tube_v[2] / len
		end
	else -- We just give something to make the robots move
		tube_v[1] = 1
		tube_v[2] = 1
	end
	return tube_v
end
	
function ComputeSpeedFromAngle(angle)
	dotProduct = 0.0;
	KProp = 20;
	wheelsDistance = 0.14;

	if angle > math.pi/2 or angle < -math.pi/2 then
		dotProduct = 0.0;
	else
		forwardVector = {math.cos(0), math.sin(0)}
		targetVector = {math.cos(angle), math.sin(angle)}
		dotProduct = forwardVector[1]*targetVector[1] + forwardVector[2]*targetVector[2]	
	end
	angularVelocity = KProp * angle;
	speeds = {dotProduct * WHEEL_SPEED - angularVelocity * wheelsDistance, dotProduct * WHEEL_SPEED + angularVelocity * wheelsDistance}

	return speeds
end

function nearest_obstacle_angle()
	nb_obstacles = 0
	best_distance = 0
	best_index = 1
	for i = 1, 24 do
		if (robot.proximity[i].value ~= 0) then
			value = robot.proximity[i].value
			if (value > best_distance) then
				best_distance = value
				best_index = i
			end
		end
	end
	return robot.proximity[best_index].angle
end

function is_tube_transported()
	if (#robot.range_and_bearing ~= 0) then
		--log("Tube is transported")
		return true
	else
		return false
	end
end

function tube_in_nest()
	closest_distance = 100
	closest_x = 0
	for x = 1, #robot.colored_blob_omnidirectional_camera
   do
      if robot.colored_blob_omnidirectional_camera[x].distance < closest_distance
      then
         	closest_distance = robot.colored_blob_omnidirectional_camera[x].distance
			--logerr("Couleur plus proche"..robot.colored_blob_omnidirectional_camera[x].color.blue)
			closest_x = x
		end
	end
	if (closest_x ~= 0) then
		if (robot.colored_blob_omnidirectional_camera[closest_x].color.blue == 255) then
			return true
		end
	end
	return false
end

function init_drop_procedure()
	log("Procedure")
   -- set timer for dropping
   dropping_timer = DROPPING_TIMEOUT
   -- find the closest LED, this is (most likely) the LED of the object being carried
   closest_distance = 100
   closest_angle = 0
   for x = 1, #robot.colored_blob_omnidirectional_camera
   do
      if robot.colored_blob_omnidirectional_camera[x].distance < closest_distance
      then
         closest_distance = robot.colored_blob_omnidirectional_camera[x].distance
         closest_angle = robot.colored_blob_omnidirectional_camera[x].angle
      end
   end
   dropping_angle = closest_angle
end

function drop_object()
   -- this is a multi-step approach that rotates the gripper into position
   log("Temps restant" .. dropping_timer)
	if dropping_timer == DROPPING_TIMEOUT then
      robot.turret.set_position_control_mode()
      robot.turret.set_rotation(dropping_angle)
      robot.wheels.set_velocity(0, 0)
   elseif dropping_timer == 0 then
      robot.gripper.unlock()
     	log("Dropped")
		unlocking_object = false
		object_gripped = false
		GRIP_COUNTER = 0
		looking_for_object = true
   end
   dropping_timer = dropping_timer - 1
end

function lock_object()
   -- this is a multi-step approach that rotates the gripper into position
   if dropping_timer == DROPPING_TIMEOUT then
      robot.turret.set_position_control_mode()
      robot.turret.set_rotation(dropping_angle)
      robot.wheels.set_velocity(0, 0)
   elseif dropping_timer == 0 then
      robot.gripper.lock_positive()
     	log("Locked")
		object_gripped = true
		GRIP_COUNTER = 0
		looking_for_lightbot = true
		looking_for_object = false
		robot.range_and_bearing.set_data(1, 4)
		turn_around = true	
		object_to_grip = false
   end
   dropping_timer = dropping_timer - 1
end


--[[ This function is executed every time you press the 'reset'
     button in the GUI. It is supposed to restore the state
     of the controller to whatever it was right after init() was
     called. The state of sensors and actuators is reset
     automatically by ARGoS. ]]
function reset()
    -- special logic to enable multi-robot opeation - do not alter this part!
    check_robot_type()

   -- put your code here, after this line
	robot.range_and_bearing.clear_data()
	object_gripped = false
	object_to_grip = false
	beginning_flocking = false
	looking_for_grdbot = false
	obstacle_found = false
	STOP = false
	looking_for_nest = true
	walking_around_nest = false
	looking_for_object = true
	looking_for_light = true
	unlocking_object = false
	check_if_in_nest = false

end

--[[ This function is executed only once, when the robot is removed
     from the simulation ]]
function destroy()
   -- put your code here, after this line

end
