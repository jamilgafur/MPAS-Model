
import numpy as np
import xarray as xr
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import os
# Creates a gif
import imageio
dpi = 200

def diff_eq(r,t,D):
    numerator_exponent = (-r**2) / (4 * D * t)
    numerator = np.e ** numerator_exponent
    denominator =  (4 * np.pi * t * D)

    return numerator / denominator

def diffusion(resTag,sliceTime):
    print("in")
# resTag is the resolution to compute
# sliceTag is the time slice, assume 1 hour output and same for all cases
    fid = open('../../../{}/default/init_step/namelist.ocean'.format(resTag),'r')
    temp = fid.readlines()

    fid.close()
    for i, line in enumerate(temp):
        if "config_cosine_bell_lat_center" in line:
            ii = line.find('=')+1
            latCent = float(line[ii:])
        if "config_cosine_bell_lon_center" in line:
            ii = line.find('=')+1
            lonCent = float(line[ii:])
        if "config_cosine_bell_radius" in line:
            ii = line.find('=')+1
            radius = float(line[ii:])
        if "config_cosine_bell_psi0" in line:
            ii = line.find('=')+1
            psi0 = float(line[ii:])
        if "config_cosine_bell_vel_pd" in line:
            ii = line.find('=')+1
            pd = float(line[ii:])
        if "config_tracer_del2" in line:
            ii = line.find('=')+1
            del2 = float(line[ii:])

    init = xr.open_dataset('../../../{}/default/init_step/ocean.nc'.format(resTag))
    #find time since the beginning of run
    ds = xr.open_dataset('../../../{}/default/forward/output/output.0001-01-01_00.00.00.nc'.format(resTag))
    tt=str(ds.xtime[sliceTime].values)
    tt.rfind('_')
    DY = float(tt[10:12])-1
    HR = float(tt[13:15])
    MN = float(tt[16:18])
    t = 86400.0*DY+HR*3600.+MN

    # calculate runtime
    totalTime = ((DY-1)*24. + HR)*3600.

    vi = 1
    simulated_center_location_x =  250000.58
    simulated_center_location_y =  216506.35 

    # update center
    xLen = init.x_period + 1
    distance = vi * totalTime
    centNew = 250000 + distance
    while centNew > xLen:
        centNew -= xLen
    xCell = ds.xCell.values
    yCell = ds.yCell.values
    time = np.linspace(30*3600, 40000*60*60, 300)
    value = np.zeros((len(time),len(xCell)))

    simulated = []
    for i in range(len(xCell)):
        distance_x = 250000. - xCell[i]
        distance_y = 216506. - yCell[i]
        r =  np.sqrt( (distance_x **2) + (distance_y**2) )
        if r < 50000.0:
            simulated.append(1)
        else:
            simulated.append(0)
    diff =[]
    for temp in range(100, len(time),10):
        t = time[temp]
        for i in range(len(xCell)):
            # get distance between xcell and the center
            distance_x = 250000. - xCell[i]
            distance_y = 216506. - yCell[i]
            r =  np.sqrt( (distance_x **2) + (distance_y**2) )
            value[temp,i] = diff_eq(r, t , del2)
        norm = [ i/max(value[temp]) for i in value[temp] ]
        diff.append(sum(np.array(simulated) - np.array(norm)))
        plt.scatter(xCell, yCell, c=norm, alpha=1)
        plt.scatter(xCell, yCell, c=simulated, alpha=.2)

        plt.title(str("{}".format(t)))
        plt.savefig(str(round(temp,2))+"_diff.png")
    
    # holds the imagenames
    images = []
    

    for temp in range(100,len(time), 10):
        images.append(imageio.imread(str(temp)+"_diff.png"))
    imageio.mimsave('study.gif', images, duration=2) 





    quit()
    values = []
    for i in range(len(init.xCell.values)):
        # get distance between xcell and the center
        distance_x = simulated_center_location_x - init.xCell[i]
        distance_y = simulated_center_location_y - init.yCell[i]

        # get the radius
        r = ( ((distance_x) **2) + (distance_y**2) ) * -2e-10
        r = r / 2      
        r = r.values
        # get diffusion 

        #tracerF = ds.tracer1[sliceTime,:,0].values
        #rmse = np.sqrt(np.mean((tracerF-tracer)**2))
        t = t + 10 
        del2 = diff_eq(r,t,10)
        values.append( del2)    
    print(values)

    init.close()
    ds.close()
    quit()

    return rmse, init.dims['nCells']




def rmse(resTag, sliceTime):
    #{{{
    # resTag is the resolution to compute RMSE
    # sliceTag is the time slice, assumes 1 hour output and same for all cases

    fid = open('../../../{}/default/init_step/namelist.ocean'.format(resTag),'r')
    temp = fid.readlines()

    fid.close()
    for i, line in enumerate(temp):
        if "config_cosine_bell_lat_center" in line: 
            ii = line.find('=')+1
            latCent = float(line[ii:])
        if "config_cosine_bell_lon_center" in line: 
            ii = line.find('=')+1
            lonCent = float(line[ii:])
        if "config_cosine_bell_radius" in line: 
            ii = line.find('=')+1
            radius = float(line[ii:])
        if "config_cosine_bell_psi0" in line: 
            ii = line.find('=')+1
            psi0 = float(line[ii:])
        if "config_cosine_bell_vel_pd" in line: 
            ii = line.find('=')+1
            pd = float(line[ii:])

    init = xr.open_dataset('../../../{}/default/init_step/initial_state.nc'.format(resTag))
    #find time since the beginning of run
    ds = xr.open_dataset('../../../{}/default/forward/output/output.0001-01-01_00.00.00.nc'.format(resTag))
    tt=str(ds.xtime[sliceTime].values)
    tt.rfind('_')
    DY = float(tt[10:12])-1
    HR = float(tt[13:15])
    MN = float(tt[16:18])
    t = 86400.0*DY+HR*3600.+MN

    #find new location of blob center
    #center is based on equatorial velocity
    R = init.sphere_radius
    distTrav = 2.0*3.14159265*R / (86400.0*pd)*t
    #distance in radians is
    distRad = distTrav / R
    newLon = lonCent + distRad
    if newLon > 2.0*np.pi:
        newLon -= 2.0*np.pi

    #construct analytic tracer
    tracer = np.zeros_like(init.tracer1[0,:,0].values)
    latC = init.latCell.values
    lonC = init.lonCell.values
    temp = R*np.arccos(np.sin(latCent)*np.sin(latC) + np.cos(latCent)*np.cos(latC)*np.cos(lonC - newLon))
    mask = temp < radius
    tracer[mask] = psi0 / 2.0 * (1.0 + np.cos(3.1415926*temp[mask]/radius))

    #oad forward mode data
    tracerF = ds.tracer1[sliceTime,:,0].values
    rmse = np.sqrt(np.mean((tracerF-tracer)**2))

    init.close()
    ds.close()
    return rmse, init.dims['nCells']
    #}}}

def main():
    #{{{
    res = ['05km']
    xtemp = []
    ytemp = []
    for i in range(len(res)):
        exec('rmse'+res[i]+',nCells'+res[i]+' = diffusion(res[i],24)')
        exec('xtemp.append(nCells'+res[i]+')')
        exec('ytemp.append(rmse'+res[i]+')')
    xdata = np.asarray(xtemp)
    ydata = np.asarray(ytemp)

    p = np.polyfit(np.log10(xdata),np.log10(ydata),1)
    conv = abs(p[0])

    yfit = xdata**p[0]*10**p[1]

    plt.loglog(xdata,yfit,'k')
    plt.loglog(xdata,ydata,'or')
    plt.annotate('Order of Convergence = {}'.format(np.round(conv,2)),xycoords='axes fraction',xy=(0.4,0.95),fontsize=14)
    plt.xlabel('Number of Grid Cells',fontsize=14)
    plt.ylabel('L2 Norm',fontsize=14)
    plt.savefig('convergence.png',bbox_inches='tight', pad_inches=0.1)
    #}}}

main()
