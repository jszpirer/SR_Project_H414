import random
import threading
import pandas as pd
from math import floor
from bs4 import BeautifulSoup
import subprocess
import re


def write_seed(bs_dat, seed):
    for tag in bs_dat.find_all('experiment'):
        tag['random_seed'] = str(seed)


def write_bots_number(bs_dat, bot_nbs):
    # 0 = cambots, 1 = groundbot, 2 = lightbot
    for tag in bs_dat.find_all('entity'):
        for sub_tag in tag.find_all('controller'):
            if sub_tag['config'] == 'cambot':
                tag['quantity'] = bot_nbs['cam']
            elif sub_tag['config'] == 'groundbot':
                tag['quantity'] = bot_nbs['ground']
            elif sub_tag['config'] == 'lightbot':
                tag['quantity'] = bot_nbs['light']

def get_final_objective_from_output(stdout, stderr):
    print(stderr)
    splits = stdout.split()
    splits.pop(-1)
    splits = splits[-1].split(sep='m')
    splits = splits[2].split(sep='\x1b')
    print('Found obj', splits[0])
    return splits[0]


def test_flex():
    with open('foraging_cp.argos', 'r') as f:
        data = f.read()

    # Use beautifulsoup to read xml 
    bs_data = BeautifulSoup(data, 'xml')
    
    # Flexibility
    swarm_size = 21
    distributions = [
            (1,1,1),
            (2,1,1),
            (1,2,1),
            (1,1,2),
            (3,1,1),
            (3,2,1),
            (3,1,2),
            (3,2,2)
            ]
    distributions = [(3,1,2),
            (3,2,2)]
    print('------------------------------')
    print('--Computation on flexibility--')
    print('------------------------------')
    f = open("results_flex.csv", 'w')
    f.write(','.join(['Exp type', 'Seed', 'nb_cam', 'nb_ground', 'nb_light', 'obj'])+'\n')
    f.close() 
    counter=0
    for d in distributions:
        total = sum(d[i] for i in range(len(d)))
        nb_lights = floor(d[2]/total * swarm_size)
        nb_ground = floor(d[1]/total * swarm_size)
        nb_cam = swarm_size - nb_lights - nb_ground
        nb_bots = {'cam': nb_cam, 'ground': nb_ground, 'light': nb_lights}

        # Write new distribution to .argos
        write_bots_number(bs_data, nb_bots)
        obj_list = []
        for i in range(10):
        #for i in range(2):
            new_seed = random.randint(1, 99999)
            write_seed(bs_data, new_seed)
            print("Running on seed", new_seed, "with distribution", d)
            

            f = open("scripted_foraging.argos", 'w')
            f.write(bs_data.prettify())
            f.close() 
            # Run simulation
            res = subprocess.run(["argos3", "-c", "scripted_foraging.argos"], capture_output=True, text=True)
            obj = get_final_objective_from_output(res.stdout, res.stderr)
            resume_list = [str(i), 'flexibility', str(new_seed), str(nb_cam), str(nb_ground), str(nb_lights), str(obj)]
            print('Computed ' + ';'.join(resume_list))
            counter += 1
            f = open("results_flex.csv", 'a')
            f.write(','.join(resume_list)+'\n')
            f.close() 


def test_scalab():
    with open('foraging_cp_scal.argos', 'r') as f:
        data = f.read()

    # Use beautifulsoup to read xml 
    bs_data = BeautifulSoup(data, 'xml')

    # Scalability
    print('------------------------------')
    print('--Computation on scalability--')
    print('------------------------------')
    f = open("results_scalab.csv", 'w')
    f.write(','.join(['Exp type', 'Seed', 'nb_cam', 'nb_ground', 'nb_light', 'obj'])+'\n')
    f.close() 

    counter=0
    init_swarm_size = 5
    d = (3, 2, 1) # To define
    for i in range(16,20):
    #for i in range(1, 2):
        swarm_size = i*init_swarm_size
        total = sum(d[j] for j in range(len(d)))
        nb_lights = floor(d[2]/total * swarm_size)
        nb_ground = floor(d[1]/total * swarm_size)
        nb_cam = swarm_size - nb_lights - nb_ground
        nb_bots = {'cam': nb_cam, 'ground': nb_ground, 'light': nb_lights}

        # Write new distribution to .argos
        write_bots_number(bs_data, nb_bots)
        for k in range(3):
        #for k in range(1):
            new_seed = random.randint(1, 99999)
            write_seed(bs_data, new_seed)
            print("Running on seed", new_seed, "with swarm size", swarm_size)

            f = open("scripted_foraging_scal.argos", 'w')
            f.write(bs_data.prettify())
            f.close()
            
            # Run simulation
            res = subprocess.run(["argos3", "-c", "scripted_foraging_scal.argos"], capture_output=True, text=True)
            obj = get_final_objective_from_output(res.stdout, res.stderr)
            resume_list = [str(i),'scalability', str(new_seed), str(nb_cam), str(nb_ground), str(nb_lights), str(obj)]
            print('Computed ' + ';'.join(resume_list))
            counter += 1
            f = open("results_scalab.csv", 'a')
            f.write(','.join(resume_list)+'\n')
            f.close() 
    print('Fin des calculs')


def main():
    flex = threading.Thread(target=test_flex)
    flex.start()
    scal = threading.Thread(target=test_scalab)
    scal.start()

    flex.join()
    scal.join()


main()
