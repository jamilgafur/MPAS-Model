#!/usr/bin/env python


import time
import psutil
import sys
import os
import subprocess
import numpy as np
import multiprocessing as mp
out, err = subprocess.Popen(['nproc'],stdout=subprocess.PIPE, stderr=subprocess.STDOUT).communicate()
nodes = 1
number_of_procs = nodes * int(out.split()[0])
print('Number of usable Processors: {}'.format(number_of_procs))
os.environ['PYTHONUNBUFFERED'] = '1'
test_failed=False

if not os.path.exists('case_outputs'):
    os.makedirs('case_outputs')

base_path = '/turquoise/usr/projects/climate/jamilg/MPAS-Model/testing_and_setup/compass'
os.chdir(base_path)



#code to save testcase_data here
testcase_data = {}
testcase_data['Baroclinic Channel 10km - Default Test'] = {'core': 'ocean', 'configuration': 'baroclinic_channel', 'resolution': '10km', 'test': 'default', 'path': 'ocean/baroclinic_channel/10km/default', 'procs': 1, 'threads': 1, 'filename': 'run_test.py', 'runnable': True, 'prereqs': []}
testcase_data['Global Ocean 240km - Init Test'] = {'core': 'ocean', 'configuration': 'global_ocean', 'resolution': 'QU240', 'test': 'init', 'path': 'ocean/global_ocean/QU240/init', 'procs': 4, 'threads': 1, 'filename': 'run.py', 'runnable': True, 'prereqs': []}
testcase_data['Global Ocean 240km - Performance Test'] = {'core': 'ocean', 'configuration': 'global_ocean', 'resolution': 'QU240', 'test': 'performance_test', 'path': 'ocean/global_ocean/QU240/performance_test', 'procs': 4, 'threads': 1, 'filename': 'run.py', 'runnable': False, 'prereqs': [{'core': 'ocean', 'configuration': 'global_ocean', 'resolution': 'QU240', 'test': 'init', 'name': 'Global Ocean 240km - Init Test'}]}
testcase_data['Global Ocean 240km - Restart Test'] = {'core': 'ocean', 'configuration': 'global_ocean', 'resolution': 'QU240', 'test': 'restart_test', 'path': 'ocean/global_ocean/QU240/restart_test', 'procs': 4, 'threads': 1, 'filename': 'run.py', 'runnable': False, 'prereqs': [{'core': 'ocean', 'configuration': 'global_ocean', 'resolution': 'QU240', 'test': 'init', 'name': 'Global Ocean 240km - Init Test'}]}
testcase_data['Global Ocean 240km - Thread Test'] = {'core': 'ocean', 'configuration': 'global_ocean', 'resolution': 'QU240', 'test': 'thread_test', 'path': 'ocean/global_ocean/QU240/thread_test', 'procs': 4, 'threads': 2, 'filename': 'run.py', 'runnable': False, 'prereqs': [{'core': 'ocean', 'configuration': 'global_ocean', 'resolution': 'QU240', 'test': 'init', 'name': 'Global Ocean 240km - Init Test'}]}
testcase_data['Global Ocean 240km - Analysis Test'] = {'core': 'ocean', 'configuration': 'global_ocean', 'resolution': 'QU240', 'test': 'analysis_test', 'path': 'ocean/global_ocean/QU240/analysis_test', 'procs': 4, 'threads': 1, 'filename': 'run.py', 'runnable': False, 'prereqs': [{'core': 'ocean', 'configuration': 'global_ocean', 'resolution': 'QU240', 'test': 'init', 'name': 'Global Ocean 240km - Init Test'}]}
testcase_data['Global Ocean 240km - BGC Ecosys Test'] = {'core': 'ocean', 'configuration': 'global_ocean', 'resolution': 'QU240', 'test': 'bgc_ecosys_test', 'path': 'ocean/global_ocean/QU240/bgc_ecosys_test', 'procs': 4, 'threads': 1, 'filename': 'run.py', 'runnable': False, 'prereqs': [{'core': 'ocean', 'configuration': 'global_ocean', 'resolution': 'QU240', 'test': 'init', 'name': 'Global Ocean 240km - Init Test'}]}
testcase_data['ZISO 20km - Smoke Test'] = {'core': 'ocean', 'configuration': 'ziso', 'resolution': '20km', 'test': 'default', 'path': 'ocean/ziso/20km/default', 'procs': 1, 'threads': 1, 'filename': 'run_test.py', 'runnable': True, 'prereqs': []}
testcase_data['ZISO 20km - Smoke Test with frazil'] = {'core': 'ocean', 'configuration': 'ziso', 'resolution': '20km', 'test': 'with_frazil', 'path': 'ocean/ziso/20km/with_frazil', 'procs': 1, 'threads': 1, 'filename': 'run_test.py', 'runnable': True, 'prereqs': []}
testcase_data['Baroclinic Channel 10km - Thread Test'] = {'core': 'ocean', 'configuration': 'baroclinic_channel', 'resolution': '10km', 'test': 'threads_test', 'path': 'ocean/baroclinic_channel/10km/threads_test', 'procs': 1, 'threads': 1, 'filename': 'run_test.py', 'runnable': True, 'prereqs': []}
testcase_data['Baroclinic Channel 10km - Decomp Test'] = {'core': 'ocean', 'configuration': 'baroclinic_channel', 'resolution': '10km', 'test': 'decomp_test', 'path': 'ocean/baroclinic_channel/10km/decomp_test', 'procs': 1, 'threads': 1, 'filename': 'run_test.py', 'runnable': True, 'prereqs': []}
testcase_data['Baroclinic Channel 10km - Restart Test'] = {'core': 'ocean', 'configuration': 'baroclinic_channel', 'resolution': '10km', 'test': 'restart_test', 'path': 'ocean/baroclinic_channel/10km/restart_test', 'procs': 4, 'threads': 1, 'filename': 'run_test.py', 'runnable': True, 'prereqs': []}
testcase_data['sub-ice-shelf 2D - restart test'] = {'core': 'ocean', 'configuration': 'sub_ice_shelf_2D', 'resolution': '5km', 'test': 'restart_test', 'path': 'ocean/sub_ice_shelf_2D/5km/restart_test', 'procs': 4, 'threads': 1, 'filename': 'run_test.py', 'runnable': True, 'prereqs': []}
testcase_data['Periodic Planar 20km - LIGHT particle region reset test'] = {'core': 'ocean', 'configuration': 'periodic_planar', 'resolution': '20km', 'test': 'region_reset_light_test', 'path': 'ocean/periodic_planar/20km/region_reset_light_test', 'procs': 1, 'threads': 1, 'filename': 'run_test.py', 'runnable': True, 'prereqs': []}
testcase_data['Periodic Planar 20km - LIGHT particle time reset test'] = {'core': 'ocean', 'configuration': 'periodic_planar', 'resolution': '20km', 'test': 'time_reset_light_test', 'path': 'ocean/periodic_planar/20km/time_reset_light_test', 'procs': 1, 'threads': 1, 'filename': 'run_test.py', 'runnable': True, 'prereqs': []}
# rewrite algorithm to read in testcase_data
# must use args.work_dir instead of os.getcwd
for key in testcase_data.keys():
  if testcase_data[key]['procs'] >  number_of_procs:
    print('test: {} has more procs ({}) than total proc allocated ({})'.format(key, testcase_data[key]['procs'],number_of_procs))
    quit()



def run(key):
    os.chdir(base_path)
    case_output = open('case_outputs/{}'.format(key.replace(" ", '_')), 'w')
    test_failed = False
    os.chdir('{}'.format(testcase_data[key]['path']))
    #print('\t\t{}--** Running case {} **'.format(number_of_procs, key))
    command = ['time', '-p', 'sleep', '5']#'./{}'.format(testcase_data[key]['filename'])]
   # print("\t\t\t{}".format(command))
    try:
        run =  subprocess.Popen(command, stdout=case_output, stderr=case_output)
    except subprocess.CalledProcessError:
        print('   ** FAIL (See case_outputs/{} for more information)'.format(key.replace(" ", '_')))
    case_output.close()

    return (run, key)


iteration = 0
done = False
compleated = []
running = []

adding_phase = True
processing_phase = False
done = False
while True:


    if len(compleated) <  len(testcase_data.keys()):
        adding_phase = True
    else:
        adding_phase = False
        done = True

    if adding_phase:
        running_names = [running_proc[1] for running_proc in running]
        for key in testcase_data.keys():
            #--------check if can run------
            if not key in compleated and not key in running_names:
            #--------if you have prereqs and it wasnt runnable----------
                if not testcase_data[key]['prereqs'] == [] and testcase_data[key]['runnable'] == False:
                    prereq_tests = [prereq['name'] for prereq in testcase_data[key]['prereqs']]
                    # check if all prereqs have been completed
                    prereq_compleated =  all(prereq in compleated for prereq in prereq_tests)
                    # -------- all prereq mets ---------
                    if prereq_compleated:
                        testcase_data[key]['runnable'] = True
                    #----------------------------------
                #========= see if we can run a key  ===========
                if number_of_procs >= testcase_data[key]['procs']:
                    number_of_procs = number_of_procs - testcase_data[key]['procs']
                    process , key = run(key) 
                    running.append((process,key))
                    print("we have enough to add: {}, {} {}".format(testcase_data[key]['procs'], number_of_procs, key))
                else:
                    print("we cant add: {}, {} {}".format(testcase_data[key]['procs'], number_of_procs, key))
                    processing_phase = True 
                    adding_phase = False
                #===========================================
            #-----------------------------------------------------------
    if processing_phase:
        print("IN PROCESSING")
        for process in running:
            pid = process[0].pid
            running_key = process[1]
            print("checking: {}".format(running_key))
            if not psutil.pid_exists(pid):
                running.remove(process)
                compleated.append(running_key)
                number_of_procs = number_of_procs + testcase_data[running_key]['procs']
                print("DONE: {} {} {}".format(testcase_data[key]['procs'], number_of_procs, running_key))
            else:
                try: 
                    process[0].wait(timeout=1)
                except subprocess.TimeoutExpired:
                    continue
        if running == []:
            processing_phase = False

    print("{} {} {}".format(adding_phase, processing_phase, done)) 
    if not adding_phase and not processing_phase and done:
        break

    iteration = iteration + 1 
    
quit()

