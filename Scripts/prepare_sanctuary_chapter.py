#!/usr/bin/env python3
"""Export generated atlas sprites and scaffold Chapter 4 without changing Chapters 1–3.
Atlas extraction is mechanical: crop each 4x6 cell and preserve its generated alpha.
"""
import argparse,json,copy,tempfile
from pathlib import Path
from PIL import Image
import numpy as np
from scipy.ndimage import label, find_objects, center_of_mass, binary_dilation
from catalog_json import dumps_catalog

NAMES=['Mossy sanctuary foundation','Ancient roots and trunk','Branching upper trunk','Great leafy crown','Left foliage','Right foliage','Stone arched gateway','Leaf-carved door','Round amber window','Arched amber window','Broken left pillar','Broken right pillar','Stone watchtower','Terracotta tower roof','Heart crystal','Crystal pedestal','Purple crystals','Timber balcony','Wooden stairs','Stone footbridge','Sacred brook','Hanging lantern','Carved bench','Forest flowers and ferns']
PLACEMENTS=[(.50,.81,.36),(.50,.63,.52),(.50,.40,.36),(.50,.20,.60),(.20,.30,.32),(.80,.31,.32),(.50,.51,.23),(.50,.56,.12),(.42,.40,.08),(.57,.42,.08),(.32,.55,.14),(.68,.55,.14),(.74,.46,.20),(.74,.35,.25),(.60,.66,.16),(.60,.77,.18),(.73,.73,.14),(.50,.61,.30),(.42,.74,.24),(.32,.82,.27),(.51,.84,.28),(.65,.53,.09),(.73,.85,.16),(.17,.82,.22)]

def export(root,name,image):
    folder=root/(name+'.imageset');folder.mkdir(parents=True,exist_ok=True)
    image.save(folder/(name+'.png'),optimize=True)
    (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':name+'.png','idiom':'universal','scale':'1x'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('atlas',type=Path)
    ap.add_argument('--chapter',type=Path,default=Path('Design/Campaign/TreeSanctuary/chapter-04.json'))
    args=ap.parse_args()
    image=Image.open(args.atlas).convert('RGBA')
    destination=Path('Backend/ContentSource/Artwork/Chapter 4')
    if destination.exists():raise FileExistsError('Chapter 4 assets already exist; preserve them rather than overwrite')
    staging=tempfile.TemporaryDirectory(prefix='.sanctuary-assets-',dir='ArrowGate')
    root=Path(staging.name)/'Chapter 4';root.mkdir(parents=True)
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
        export(root,f'ForestSanctuaryPiece{index+1:02d}',tile)
    export(root,'ForestSanctuaryComplete',Image.open('Design/Campaign/TreeSanctuary/sanctuary-complete.png').convert('RGBA'))
    original=json.loads(Path('Backend/ContentSource/Levels/chapter-01.json').read_text())
    chapter=copy.deepcopy(original['chapter']);chapter.update(id=4,name='The Ancient Tree Sanctuary',subtitle='Awaken the heart of the ancient forest',symbol='sparkles')
    chapter['style'].update(primaryColor='#287876',secondaryColor='#8656A0',backgroundColor='#E5F1E8',decorations=['✧','❧','✦'])
    chapter['assembly'].update(assetPrefix='ForestSanctuaryPiece',finalArtwork='ForestSanctuaryComplete',placements=[dict(x=x,y=y,scale=s) for x,y,s in PLACEMENTS])
    levels=[]
    for index,source in enumerate(original['levels']):
        level=copy.deepcopy(source);level.update(id=76+index,chapterID=4,completionArtwork=f'ForestSanctuaryPiece{index+1:02d}' if index<24 else 'ForestSanctuaryComplete',rewardName='The Ancient Tree Sanctuary · '+(NAMES[index] if index<24 else 'Complete sanctuary'))
        if index==0:level.update(timeLimit=120,difficulty='easy')
        levels.append(level)
    args.chapter.parent.mkdir(parents=True,exist_ok=True)
    args.chapter.write_text(dumps_catalog({'chapter':chapter,'levels':levels})+'\n')
    # Assembly preview uses the exact transforms used by the SwiftUI Gallery.
    canvas=Image.new('RGBA',(1000,1000),(0,0,0,0))
    for image,(x,y,scale) in zip(pieces,PLACEMENTS):
        sprite=image.copy();sprite.thumbnail((round(1000*scale),round(1000*scale)),Image.Resampling.LANCZOS)
        canvas.alpha_composite(sprite,(round(1000*x-sprite.width/2),round(1000*y-sprite.height/2)))
    canvas.save('Design/Campaign/TreeSanctuary/assembly-preview.png')
    root.rename(destination)
    staging.cleanup()
    print('Exported 24 transparent sprites and complete sanctuary; Chapter 4 scaffold ready.')

if __name__=='__main__':main()
