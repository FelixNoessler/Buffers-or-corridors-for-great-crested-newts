import sys
from multiprocessing import Pool
import os
import pandas as pd
import pyNetLogo
from SALib.sample import saltelli


def initializer(modelfile):
    global netlogo
    netlogo = pyNetLogo.NetLogoLink(netlogo_home='NetLogo',
                                    netlogo_version='6.2',
                                    gui=False)
    netlogo.load_model(modelfile)


def run_simulation(experiment):
    for key, value in experiment.items():
        netlogo.command(f'set {key} {value}')

    netlogo.command('setup')

    # fixed parameters:
    netlogo.command('set max-timesteps 50')
    netlogo.command('set number-of-startind 40')
    netlogo.command('set cropland-movement-cost 5')
    netlogo.command('set woodland-movement-cost 1')
    netlogo.command('set angle-for-viewing-ponds-and-woodland 140') 

    # reporter:
    step_reporter = ['count newts',
                     'occupied-ponds']
    
    # start with corridors:
    netlogo.command('set current-scenario "corridors"')    
    netlogo.repeat_command('go', 40)
    out_corridor =  netlogo.repeat_report(step_reporter, 10, go='go')

    # then buffer:
    netlogo.repeat_command('go', 40)
    out_buffer =  netlogo.repeat_report(step_reporter, 10, go='go')
    
    out = [netlogo.report('newts-buffer'),
           netlogo.report('newts-corridor'),
           netlogo.report('occupied-ponds-buffer'),
           netlogo.report('occupied-ponds-corridor'),
           out_buffer['count newts'].values.mean(),
           out_buffer['occupied-ponds'].values.mean(),
           out_corridor['count newts'].values.mean(),
           out_corridor['occupied-ponds'].values.mean()]

    results = pd.Series(out,
                        index=['newts_buffer', 'newts_corridor',
                               'ponds_buffer', 'ponds_corridor',
                               'mean_newts_buffer', 'mean_ponds_buffer',
                               'mean_newts_corridor', 'mean_ponds_corridor'])
    #print(results)
    return results




def generate_samples(n):
    problem = {
        'num_vars': 7,
        'names': [
            #'number-of-startind', # 15
            'capacity',  # 20
            'mean-juvenile-mortality-prob', # 0.5
            'mean-adult-mortality-prob', #0.2
            #'cropland-movement-cost', #5
            #'woodland-movement-cost', #1
            #'angle-for-viewing-ponds-and-woodland', #140
            'mortality-decrease-with-buffer', #0.1
            'distance-for-viewing-ponds-and-woodland', #2
            'movement-energy', #700
            'mean-number-of-female-offspring' #5
        ],
        'bounds': [
            #[5, 80],
            [10, 40],
            [0.4, 0.7],
            [0.1, 0.3],
            #[4, 6],
            #[0.5, 2],
            #[70, 180],
            [0.01, 0.2],
            [0.5, 3],
            [200, 1000],
            [4, 6]
        ]
    }
    param_values = saltelli.sample(problem,
                                   n,
                                   calc_second_order=True)

    df = pd.DataFrame(param_values,
                      columns=problem['names'])

    return df

if __name__ == '__main__':
    modelfile = 'model/crested_newt.nlogo'

    #experiments = generate_samples(1024)
    #experiments.to_csv('parameter_new.csv')

   

    ind = [i * 256 for i in range(0, 64 + 1)]
    parameter_df = pd.read_csv('parameter_new.csv', index_col=0)
    #print(len(parameter_df))
    #print(ind)
    #print(len(ind))
    #sys.exit(0)

    
    for i in range(29, 64):
        print(ind[i], ind[i+1])
        experiments = parameter_df.iloc[ind[i]:ind[i+1]]
        results = []
        with Pool(initializer=initializer, initargs=(modelfile,), processes=50) as executor:
           for entry in executor.map(run_simulation, experiments.to_dict('records')):
               results.append(entry)
               print('yap!')

           results = pd.DataFrame(results)

        results.to_csv(f'sobol_sensitivity/results_{ind[i]}_{ind[i+1]}.csv')
        print(results)


