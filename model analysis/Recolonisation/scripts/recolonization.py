from multiprocessing import Pool
import os, sys
import pandas as pd
import numpy as np
import pyNetLogo


def initializer():
    global netlogo
    netlogo = pyNetLogo.NetLogoLink(netlogo_home='NetLogo',
                                    netlogo_version='6.2',
                                    gui=False)
    netlogo.load_model('model/crested_newt.nlogo')



def run_scenario():
    for i in range(250):
        newts_pond_one = netlogo.report('count newts with [pond-id = 1]')

        if newts_pond_one == 0:
            netlogo.command('go')
        else:
            total_newts = netlogo.report('count newts')
            netlogo.command('reset-ticks')
            netlogo.command('tick-advance 249') 
            netlogo.command('go')           
            return total_newts, i

    total_newts = netlogo.report('count newts')
    return total_newts, -999


def run_simulation(parameter):

    netlogo.command('set one-pond-without-starting-newts true')
    netlogo.command('set current-scenario "corridors"')
    netlogo.command('setup')
  
    # fixed parameters:
    netlogo.command('set max-timesteps 250')
    netlogo.command('set number-of-startind 30')
    netlogo.command('set cropland-movement-cost 5')
    netlogo.command('set woodland-movement-cost 1')
    netlogo.command('set angle-for-viewing-ponds-and-woodland 140') 
    netlogo.command('set capacity 20')
    netlogo.command('set mean-juvenile-mortality-prob 0.5')
    netlogo.command('set mean-adult-mortality-prob 0.2')
    netlogo.command('set distance-for-viewing-ponds-and-woodland 2')
    netlogo.command('set mean-number-of-female-offspring 5')

    
    # variable parameters:
    mort_decr, energy = parameter
    print(mort_decr, energy) 
    netlogo.command(f'set mortality-decrease-with-buffer {mort_decr}')
    netlogo.command(f'set movement-energy {energy}')


    corridor_netws, corridor_year = run_scenario()
    buffer_netws, buffer_year = run_scenario()

    
    out = [mort_decr,
           energy,
           corridor_netws,
           corridor_year,
           buffer_netws,
           buffer_year]

    results = pd.Series(out,
                        index=['mortality_decrease', 'movement_energy',
                               'corridor_netws', 'corridor_year',
                               'buffer_netws', 'buffer_year'])
    return results



if __name__ == '__main__':

    # 10 * 10 parameter combinations with 10 repeats
    # --> 1000 simulations
    
    # parameter
    mort_decr = np.linspace(0.01, 0.15, 10)
    movement_energy = np.linspace(200, 1000, 10)

    # parameter combinations
    mesh = np.array(np.meshgrid(mort_decr, movement_energy))
    combinations = mesh.T.reshape(-1, 2)
    combinations_repeats = np.tile(combinations, (10,1))
    
    for i in range(4):
        combinations_part = combinations_repeats[i*250:i*250+250]
        results = []
        with Pool(initializer=initializer, processes=50) as executor:
           for entry in executor.map(run_simulation, combinations_part):
                results.append(entry)
           results = pd.DataFrame(results)

        results.to_csv(f'recolonization_experiment_{i}.csv')

    

