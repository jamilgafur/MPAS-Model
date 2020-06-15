from glob import glob
import xarray as xr
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.image import imread
import numpy as np
import os

def get_RMSE(folder_name):
  """
  calculates the RMSE of a given resolution
  """

  print(os.getcwd())
  KPP = glob("../../"+folder_name+"/default/forward/output/*")
  print(KPP)
  KPP = KPP[0]
  print("Processing... {}".format(KPP))


  data = xr.open_dataset(KPP)


  # the center and radius of the cylindars starting point
  simulated_center_location_x =  250000.58
  simulated_center_location_y =  216506.35 
  radius = 50000
  vi = 1
  nt = 30

  # grab the time in hours, and days
  t1 = str(data.xtime[nt].values)
  sp=t1.find('_')+1
  hr = float(t1[sp:sp+2])
  day = float(t1[sp-3:sp-1])

  # calculate runtime
  totalTime = ((day-1)*24. + hr)*3600.

  # update center
  xLen = data.x_period
  distance = vi * totalTime
  centNew = 250000 + distance

  #print(centNew)
  while centNew > xLen:
    centNew -= xLen
  
  # get last timeslice and create a temparray 
  tracerE = np.zeros_like(data.tracer1[-1,:,0].values)

  # xDist = xCell(iCell) - config_horizontal_advection_x_cent
  #yDist = yCell(iCell) - config_horizontal_advection_y_cent
  #debugTracers(:,:,iCell) = exp(-config_horizontal_advection_gaussian_width*(xDist**2.0 + yDist**2.0))


  for i in range(len(data.xCell.values)):
    # get distance between xcell and the center
    distance_x = simulated_center_location_x - data.xCell[i]
    distance_y = simulated_center_location_y - data.yCell[i]
    # if a point is inside the circle set its simulated value to 1
    tracerE[i] = ( ((distance_x) **2) + (distance_y**2) ) * -2e-10 
    tracerE[i] = np.exp(tracerE[i])
 
  #plt.scatter(data.xCell, data.yCell, c=tracerE, vmin=0, vmax=1)
  #plt.savefig(folder_name + "_simulated.png")
  #plt.scatter(data.xCell, data.yCell, c=data.tracer1[-1,:,0], vmin=0 , vmax=1)
  #plt.savefig(folder_name +"_real.png")
  # get the RMSE of the simulated values to the actual values
  rmse = np.sqrt(np.mean(tracerE - data.tracer1[-1,:,0].values)**2)

  print("For  {} RMSE = {}".format(folder_name, rmse))

  # return the int(resolution) and the float(rmse)
  return int(folder_name[0:folder_name.find("km")]) , float(rmse)
  

def main():
  folders = ["05km", "10km", "25km"]
  resolution = []
  rmse = []
  for folder in folders:
    x,y = get_RMSE(folder)
    resolution.append(x)
    rmse.append(y)
  
  print(resolution)
  print(rmse)
  quit()
  # find line of best fit
  resolution = np.array(resolution)
  rmse = np.array(rmse)

  m,b = np.polyfit(resolution, rmse,1)
  print("f(x) = m * x + B\n\tm: {}\n\tb: {}".format(m,b))

  luke_value =  np.log( (rmse[-1] / rmse[0]) ) / np.log( (resolution[0] - resolution[-1]) )
  print("{} = log(rmse(25k) / rmse(5km)) / log(25/5)".format(luke_value))

  points = np.linspace(min(resolution), max(resolution),100)
  plt.plot(points, m*points+b)
  plt.title("y = {} x + {}".format(m,b))
  plt.yscale("log")
  plt.scatter(resolution,rmse)
  plt.savefig("rmse.png")


main()
