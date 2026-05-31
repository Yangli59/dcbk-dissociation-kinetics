import subprocess
import numpy as np
import os
import argparse

def run_command(command, error_message):
    """Run a shell command and handle errors."""
    try:
        subprocess.run(command, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error: {error_message}")
        print(e)
        exit(1)

def parse_dis_file(dis_file):
    """Parse the dis_{Num}.out file and return the distances."""
    distances = []
    with open(dis_file, 'r') as fo:
        for line in fo:
            if '#' not in line:
                try:
                    dis = float(line.split()[-1])
                    distances.append(dis)
                except (ValueError, IndexError):
                    continue
    return distances

def main():
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('-gpu', metavar='GPU', type=int, nargs='?', help='an integer for the GPU id')

    args = parser.parse_args()

    if args.gpu is not None:
        os.environ['CUDA_VISIBLE_DEVICES'] = str(args.gpu)
        print(f'Set CUDA_VISIBLE_DEVICES to {args.gpu}')

    Work_Dic = os.getcwd()
    seed = 0
    Num = 1
    X = [1, 2, 3, 4, 5, 6, 7, 8]
    Ini = 0

    # Initial command
    command_1 = [
        'pmemd.cuda', '-O', '-i', 'SuMD.in', '-o', 'SuMD_1.out', '-p', 'comp_sol.prmtop',
        '-c', 'SuMD_0.rst', '-r', 'SuMD_1.rst', '-x', 'SuMD_1.nc'
    ]
    run_command(command_1, "Failed to run the initial pmemd.cuda command.")

    # Start loop
    while seed <= 30:
        Y = []
        cpp_file_content = f'''
trajin SuMD_{Num}.nc 1 -1 10
reference comp_sol.inpcrd [last]
rms rms1 ref [last] :2-237@CA,N,C,O out rms.dat
rms rms2 ref [last] :1&!@H= out rms_lig.out nofit
distance dis1 :1&!@H= :52,94,110@CA out dis_{Num}.out 
go
'''
        with open('rms.in', 'w') as cpp_file:
            cpp_file.write(cpp_file_content)

        cpp_command = ['cpptraj', '-p', 'comp_sol.prmtop', '-i', 'rms.in']
        run_command(cpp_command, "Failed to run cpptraj command.")

        # Parse the dis_{Num}.out file
        Y = parse_dis_file(f'dis_{Num}.out')

        if len(Y) < 8:
            print(f"Error: Not enough data points in dis_{Num}.out. Expected at least 8, got {len(Y)}.")
            exit(1)

        seed = max(Y)
        Z = np.polyfit(X, Y, 1)
        m = Z[0]
        
        if Y[7] > Y[0] and m > 0:
            if Y[7] > Ini:  
                Ini = Y[7] 
                command = [
                    'pmemd.cuda', '-O', '-i', 'SuMD.in', '-o', f'SuMD_{Num+1}.out',
                    '-p', 'comp_sol.prmtop', '-c', f'SuMD_{Num}.rst', '-r', f'SuMD_{Num+1}.rst',
                    '-x', f'SuMD_{Num+1}.nc'
                ]
                subprocess.run(command)
                Num += 1
            else:
                
                command = [
                    'pmemd.cuda', '-O', '-i', 'SuMD.in', '-o', f'SuMD_{Num}.out',
                    '-p', 'comp_sol.prmtop', '-c', f'SuMD_{Num-1}.rst', '-r', f'SuMD_{Num}.rst',
                    '-x', f'SuMD_{Num}.nc'
                ]
                subprocess.run(command)
        else:
            command = [
                'pmemd.cuda', '-O', '-i', 'SuMD.in', '-o', f'SuMD_{Num}.out',
                '-p', 'comp_sol.prmtop', '-c', f'SuMD_{Num-1}.rst', '-r', f'SuMD_{Num}.rst',
                '-x', f'SuMD_{Num}.nc'
            ]
            run_command(command, "Failed to run pmemd.cuda command for current step.")

    # End of the SuMD process
    run_command(['cp', f'SuMD_{Num}.rst', 'prod0.rst'], "Failed to copy the final rst file.")
    run_command(['sh', os.path.join(Work_Dic, 'CMD.sh')], "Failed to run CMD.sh.")

if __name__ == "__main__":
    main()