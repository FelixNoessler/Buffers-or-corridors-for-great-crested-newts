import scipy.spatial as sci_spatial
import skimage.draw as ski_draw
import shapely.geometry as shapely_geom 
import numpy as np
import os, sys

def create_landscape(no_of_circles, radius):
    
    # create the middle points of the ponds (the ponds should not overlap)
    x,y = np.random.randint(0,400), np.random.randint(0,400)
    list_of_points = [(x + 400, y + 400), 
                      (x + 400, y), 
                      (x + 800, y + 400), 
                      (x + 400, y + 800), 
                      (x, y + 400)]

    for i in range(no_of_circles-1):
        new_point_found = False
        trials = 0

        while not new_point_found and trials < 500:
            x,y = np.random.randint(0,400), np.random.randint(0,400)
            new_point = shapely_geom.Point((x + 400, y + 400))
            trials += 1

            if not new_point.buffer(radius * 2 + 50).intersects(shapely_geom.MultiPoint(list_of_points)):
                new_point_found = True

                list_of_points.append((x + 400, y + 400))
                list_of_points.append((x + 400, y))
                list_of_points.append((x + 800, y + 400))
                list_of_points.append((x + 400, y + 800))
                list_of_points.append((x, y + 400))     

    # landscape with ponds
    ponds_img = np.full((1200 + 2*radius, 1200 + 2*radius), 55)
    
    # draw the ponds
    for point_i in list_of_points:
        rr, cc = ski_draw.disk(point_i, radius)
        ponds_img[rr + radius, cc +  radius] = 105

    ponds_img = ponds_img[400+radius : 800+radius, 400+radius : 800+radius]
    
    
    # pond-id
    ponds_id_img = np.full((1200 + 2*radius, 1200 + 2*radius), -999)
    
    # draw the ponds
    id_i = 0

    for point_i, id_i in zip(list_of_points, np.repeat(np.arange(len(list_of_points)/5), 5)):
        rr, cc = ski_draw.disk(point_i, radius)
        ponds_id_img[rr + radius, cc +  radius] = id_i
        

    ponds_id_img = ponds_id_img[400+radius : 800+radius, 400+radius : 800+radius]  

    # create an raster image with the middle points marked
    is_center_img = np.zeros_like(ponds_img)
    
    boundary = shapely_geom.Polygon([(399, 399), (799, 399), (799, 799), (399, 799)])
    selection = [shapely_geom.Point(point_i).intersects(boundary) for point_i in list_of_points]
    x,y = np.array(list_of_points)[selection].T
    x -= 400
    y -= 400
    is_center_img[x, y] = 1

    
    return is_center_img, ponds_img, ponds_id_img

def make_corridors(is_center, ponds):
    without_boundaries = np.zeros((400*3, 400*3))
    without_boundaries[0:400, 400:800] = is_center
    without_boundaries[400:800, 0:400] = is_center
    without_boundaries[400:800, 400:800] = is_center
    without_boundaries[800:1200, 400:800] = is_center
    without_boundaries[400:800, 800:1200] = is_center

    loc = np.where(without_boundaries == 1)
    center_points = np.swapaxes(loc, 0, 1)
    result = sci_spatial.distance.cdist(center_points, center_points)

    new_img = np.full_like(without_boundaries, 55)  # 55 --> green in netlogo
    points_with_corridors = np.where(np.logical_and( result != 0, result < 170)) #mean(result[result != 0]) * 0.3

    for i in np.arange(0, np.shape(points_with_corridors)[1]):

        index_from = points_with_corridors[0][i]
        index_to = points_with_corridors[1][i]

        x = [loc[1][index_from], loc[1][index_to]]
        y = [loc[0][index_from], loc[0][index_to]]

        x_corr, y_corr = shapely_geom.LineString([(x[0], y[0]), (x[1], y[1])]).buffer(4.5).exterior.coords.xy

        rr, cc = ski_draw.polygon(y_corr, x_corr, without_boundaries.shape)
        new_img[rr, cc] = 35 # 35 --> brown in netlogo

    final_img = new_img[400:800, 400:800] 
    final_img[np.where(ponds == 105)] = 105 # 105 --> blue in netlogo
    
    return final_img

def make_buffers(corridor_img, is_center_img):
    radius = 15
    
    corridor_area = np.sum(corridor_img == 35)
    no_of_ponds = np.sum(is_center_img)
    
    
    buffer_radius = np.sqrt(  ( (corridor_area / no_of_ponds) + np.pi *radius **2)  / np.pi )

    without_boundaries = np.zeros((400*3, 400*3))
    without_boundaries[0:400, 400:800] = is_center_img
    without_boundaries[400:800, 0:400] = is_center_img
    without_boundaries[400:800, 400:800] = is_center_img
    without_boundaries[800:1200, 400:800] = is_center_img
    without_boundaries[400:800, 800:1200] = is_center_img

    x,y = np.where(without_boundaries == 1)
    new_img = np.full_like(without_boundaries, 55)  # 55 --> green in netlogo

    # make buffers
    for x_i, y_i in zip(x,y):
        rr, cc = ski_draw.disk((x_i, y_i), buffer_radius)

        filter_1 = (rr >= 0) & (rr <= 1199)
        filter_2 = (cc >= 0) & (cc <= 1199)
        rr = rr[filter_1 & filter_2]
        cc = cc[filter_1 & filter_2]
        new_img[rr, cc] = 35

    # make ponds
    for x_i, y_i in zip(x,y):
        rr, cc = ski_draw.disk((x_i, y_i), radius)

        filter_1 = (rr >= 0) & (rr <= 1199)
        filter_2 = (cc >= 0) & (cc <= 1199)
        rr = rr[filter_1 & filter_2]
        cc = cc[filter_1 & filter_2]
        new_img[rr, cc] = 105
        
    return new_img[400:800, 400:800]


if __name__ == "__main__":
    #print('Scenario-Number:', sys.argv[1])
    
    os.makedirs('gis_output/' + sys.argv[1])
    os.chdir('gis_output/' + sys.argv[1])

    is_center_of_pond, pond, pond_id = create_landscape(no_of_circles=int(sys.argv[2]), radius=int(sys.argv[3]))
    corridors = make_corridors(is_center_of_pond, pond)
    buffers = make_buffers(corridors, is_center_of_pond)

    with open("../pcolor.asc") as myfile:
        head = [next(myfile) for x in range(6)]

    np.savetxt('corridors.asc',corridors, fmt='%i', newline='\n', header=''.join(head)[:-1], comments='')
    np.savetxt('buffers.asc',buffers, fmt='%i', newline='\n', header=''.join(head)[:-1], comments='')
    np.savetxt('center.asc',is_center_of_pond, fmt='%i', newline='\n', header=''.join(head)[:-1], comments='')
    np.savetxt('id.asc',pond_id, fmt='%i', newline='\n', header=''.join(head)[:-1], comments='')
