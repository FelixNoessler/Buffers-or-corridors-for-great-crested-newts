import sys
from multiprocessing import Pool
import os
import pandas as pd
import pyNetLogo
from SALib.sample import saltelli


def initializer(modelfile):
    global netlogo
    netlogo = pyNetLogo.NetLogoLink(netlogo_home='/home/felix/Software/NetLogo/',
                                    netlogo_version='6.2',
                                    gui=False)
    netlogo.load_model(modelfile)


def run_simulation(experiment):
    for key, value in experiment.items():
        if key == 'random-seed':
            netlogo.command(f'random-seed {value}')
        else:
            netlogo.command(f'set {key} {value}')

    netlogo.command('setup')
    steps = 50
    netlogo.command(f'set max-timesteps {steps}')
    netlogo.repeat_command('go', 2*steps)

    results = pd.Series([netlogo.report('newts-buffer'),
                         netlogo.report('newts-corridor'),
                         netlogo.report('occupied-ponds-buffer'),
                         netlogo.report('occupied-ponds-corridor')],
                        index=['newts_buffer', 'newts_corridor',
                               'ponds_buffer', 'ponds_corridor'])
    return results




def generate_samples(n = 500):
    problem = {
        'num_vars': 11,
        'names': [
            'number-of-startind', # 15
            'capacity',  # 20
            'mean-juvenile-mortality-prob', # 0.5
            'mean-adult-mortality-prob', #0.2
            'cropland-movement-cost', #5
            'woodland-movement-cost', #1
            'angle-for-viewing-ponds-and-woodland', #140
            'mortality-decrease-with-buffer', #0.1
            'distance-for-viewing-ponds-and-woodland', #2
            'movement-energy', #700
            'mean-number-of-female-offspring' #5
        ],
        'bounds': [
            [5, 80],
            [10, 40],
            [0.4, 0.7],
            [0.1, 0.3],
            [4, 6],
            [0.5, 2],
            [70, 180],
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

    #experiments = generate_samples(200)
    #experiments.to_csv('parameter.csv')

    ind = [i * 120 for i in range(0, 40 + 1)]
    parameter_df = pd.read_csv('parameter.csv', index_col=0)


    for i in range(0, 15):
        print(ind[i], ind[i+1])
        experiments = parameter_df.iloc[ind[i]:ind[i+1]]

        with Pool(initializer=initializer, initargs=(modelfile,), processes=12) as executor:
           results = []
           for entry in executor.map(run_simulation, experiments.to_dict('records')):
               results.append(entry)
           results = pd.DataFrame(results)

        results.to_csv(f'results_{ind[i]}_{ind[i+1]}.csv')
        print(results)
