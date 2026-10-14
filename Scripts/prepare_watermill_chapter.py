#!/usr/bin/env python3
"""Export generated atlas sprites and scaffold Chapter 2 without changing Chapter 1.
Atlas extraction is mechanical: crop each 4x6 cell and preserve its generated alpha.
"""
import argparse,json,copy
from pathlib import Path
from PIL import Image
import numpy as np
from scipy.ndimage import label, find_objects, center_of_mass, binary_dilation
from catalog_json import dumps_catalog

NAMES=['Mossy foundation','Stone facade','Timber gable','Tiled roof','Chimney','Waterwheel','Wheel support','Forest stream','Footbridge','Teal door','Window and shutters','Amber window','Flower box','Leafy canopy','Tree trunk','Mossy boulders','Flour sacks','Wooden barrel','Lantern','Water chute','Reeds','Mushrooms','Wildflowers','Stone steps']
PLACEMENTS=[(.5,.74,.50),(.5,.50,.48),(.5,.31,.45),(.5,.25,.58),(.64,.24,.13),(.76,.59,.34),(.84,.70,.15),(.5,.79,.40),(.22,.81,.30),(.43,.58,.13),(.43,.34,.13),(.60,.51,.10),(.43,.43,.15),(.19,.27,.37),(.19,.50,.25),(.66,.82,.22),(.61,.68,.13),(.31,.67,.12),(.34,.55,.08),(.75,.41,.26),(.87,.85,.16),(.15,.89,.14),(.44,.75,.17),(.41,.72,.22)]

def export(root,name,image):
    folder=root/(name+'.imageset');folder.mkdir(parents=True,exist_ok=True)
    image.save(folder/(name+'.png'),optimize=True)
    (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':name+'.png','idiom':'universal','scale':'1x'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('atlas',type=Path)
    ap.add_argument('--chapter',type=Path,default=Path('Design/Campaign/Watermill/chapter-02.json'))
    args=ap.parse_args()
    image=Image.open(args.atlas).convert('RGBA')
    root=Path('ArrowGate/Assets.xcassets/Chapter 2');root.mkdir(parents=True,exist_ok=True)
    (root/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}},indent=2)+'\n')
    # Segment atlas objects globally rather than cutting on cell boundaries:
    # a sprite may extend a few pixels into a neighboring gutter.
    alpha=np.array(image.getchannel('A'))
    labels,count=label(alpha>=64)
    regions=find_objects(labels);sizes=np.bincount(labels.ravel())
    slots={}
    for region_id in np.argsort(sizes[1:])[::-1]+1:
        cy,cx=center_of_mass(alpha>=64,labels,int(region_id))
        slot=min(5,int(cy*6/image.height))*4+min(3,int(cx*4/image.width))
        if slot not in slots:slots[slot]=int(region_id)
        if len(slots)==24:break
    if len(slots)!=24:raise ValueError('Atlas does not contain 24 separate objects')
    pieces=[]
    for index in range(24):
        region_id=slots[index];ys,xs=regions[region_id-1]
        bounds=(max(0,xs.start-3),max(0,ys.start-3),min(image.width,xs.stop+3),min(image.height,ys.stop+3))
        tile=image.crop(bounds)
        keep=binary_dilation(labels[bounds[1]:bounds[3],bounds[0]:bounds[2]]==region_id,iterations=3)
        tile_alpha=np.array(tile.getchannel('A'));tile_alpha[~keep]=0
        tile.putalpha(Image.fromarray(tile_alpha))
        pieces.append(tile)
        export(root,f'ForestWatermillPiece{index+1:02d}',tile)
    export(root,'ForestWatermillComplete',Image.open('Design/Campaign/Watermill/watermill-complete.png').convert('RGBA'))
    original=json.loads(Path('ArrowGate/Levels/chapter-01.json').read_text())
    chapter=copy.deepcopy(original['chapter']);chapter.update(id=2,name='The Woodland Watermill',subtitle='Bring the forest stream to life',symbol='water.waves')
    chapter['style'].update(primaryColor='#237A84',secondaryColor='#BA613B',backgroundColor='#E4F1EB',decorations=['≈','❧','✦'])
    chapter['assembly'].update(assetPrefix='ForestWatermillPiece',finalArtwork='ForestWatermillComplete',placements=[dict(x=x,y=y,scale=s) for x,y,s in PLACEMENTS])
    levels=[]
    for index,source in enumerate(original['levels']):
        level=copy.deepcopy(source);level.update(id=26+index,chapterID=2,completionArtwork=f'ForestWatermillPiece{index+1:02d}' if index<24 else 'ForestWatermillComplete',rewardName='The Woodland Watermill · '+(NAMES[index] if index<24 else 'Complete watermill'))
        if index==0:level.update(timeLimit=120,difficulty='easy')
        levels.append(level)
    args.chapter.parent.mkdir(parents=True,exist_ok=True)
    args.chapter.write_text(dumps_catalog({'chapter':chapter,'levels':levels})+'\n')
    # Assembly preview uses the exact transforms used by the SwiftUI Gallery.
    canvas=Image.new('RGBA',(1000,1000),(0,0,0,0))
    for image,(x,y,scale) in zip(pieces,PLACEMENTS):
        sprite=image.copy();sprite.thumbnail((round(1000*scale),round(1000*scale)),Image.Resampling.LANCZOS)
        canvas.alpha_composite(sprite,(round(1000*x-sprite.width/2),round(1000*y-sprite.height/2)))
    canvas.save('Design/Campaign/Watermill/assembly-preview.png')
    print('Exported 24 transparent sprites and complete watermill; Chapter 2 scaffold ready.')

if __name__=='__main__':main()
