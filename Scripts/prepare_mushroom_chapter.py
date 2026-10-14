#!/usr/bin/env python3
"""Export generated atlas sprites and scaffold Chapter 3 without changing Chapters 1 and 2.
Atlas extraction is mechanical: crop each 4x6 cell and preserve its generated alpha.
"""
import argparse,json,copy
from pathlib import Path
from PIL import Image
import numpy as np
from scipy.ndimage import label, find_objects, center_of_mass, binary_dilation
from catalog_json import dumps_catalog

NAMES=['Mossy village foundation','Central mushroom house','Red spotted cap','Small left cottage','Orange mushroom cap','Small right cottage','Burgundy mushroom cap','Stone chimney','Timber balcony','Teal front door','Honey wooden door','Round amber window','Window with shutters','Wooden stairs','Forest footbridge','Village brook','Leafy canopy','Tree trunk','Amber lantern','Mossy boulders','Wooden barrel','Little bench','Flowerpots','Fern and mushrooms']
PLACEMENTS=[(.50,.79,.40),(.50,.48,.45),(.50,.27,.50),(.23,.64,.30),(.23,.50,.35),(.77,.60,.28),(.77,.46,.34),(.60,.19,.13),(.50,.58,.28),(.50,.60,.12),(.23,.68,.10),(.50,.42,.10),(.77,.57,.12),(.50,.72,.20),(.33,.83,.25),(.50,.86,.25),(.13,.29,.23),(.13,.46,.19),(.59,.54,.09),(.80,.77,.17),(.39,.75,.10),(.70,.79,.15),(.63,.74,.12),(.85,.86,.16)]

def export(root,name,image):
    folder=root/(name+'.imageset');folder.mkdir(parents=True,exist_ok=True)
    image.save(folder/(name+'.png'),optimize=True)
    (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':name+'.png','idiom':'universal','scale':'1x'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('atlas',type=Path)
    ap.add_argument('--chapter',type=Path,default=Path('Design/Campaign/MushroomVillage/chapter-03.json'))
    args=ap.parse_args()
    image=Image.open(args.atlas).convert('RGBA')
    root=Path('ArrowGate/Assets.xcassets/Chapter 3');root.mkdir(parents=True,exist_ok=True)
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
        export(root,f'ForestMushroomPiece{index+1:02d}',tile)
    export(root,'ForestMushroomComplete',Image.open('Design/Campaign/MushroomVillage/mushroom-complete.png').convert('RGBA'))
    original=json.loads(Path('ArrowGate/Levels/chapter-01.json').read_text())
    chapter=copy.deepcopy(original['chapter']);chapter.update(id=3,name='The Mushroom Village',subtitle='A little village beneath the forest caps',symbol='leaf.fill')
    chapter['style'].update(primaryColor='#924D3E',secondaryColor='#4E794C',backgroundColor='#F4EBDF',decorations=['✿','❧','✦'])
    chapter['assembly'].update(assetPrefix='ForestMushroomPiece',finalArtwork='ForestMushroomComplete',placements=[dict(x=x,y=y,scale=s) for x,y,s in PLACEMENTS])
    levels=[]
    for index,source in enumerate(original['levels']):
        level=copy.deepcopy(source);level.update(id=51+index,chapterID=3,completionArtwork=f'ForestMushroomPiece{index+1:02d}' if index<24 else 'ForestMushroomComplete',rewardName='The Mushroom Village · '+(NAMES[index] if index<24 else 'Complete village'))
        if index==0:level.update(timeLimit=120,difficulty='easy')
        levels.append(level)
    args.chapter.parent.mkdir(parents=True,exist_ok=True)
    args.chapter.write_text(dumps_catalog({'chapter':chapter,'levels':levels})+'\n')
    # Assembly preview uses the exact transforms used by the SwiftUI Gallery.
    canvas=Image.new('RGBA',(1000,1000),(0,0,0,0))
    for image,(x,y,scale) in zip(pieces,PLACEMENTS):
        sprite=image.copy();sprite.thumbnail((round(1000*scale),round(1000*scale)),Image.Resampling.LANCZOS)
        canvas.alpha_composite(sprite,(round(1000*x-sprite.width/2),round(1000*y-sprite.height/2)))
    canvas.save('Design/Campaign/MushroomVillage/assembly-preview.png')
    print('Exported 24 transparent sprites and complete village; Chapter 3 scaffold ready.')

if __name__=='__main__':main()
