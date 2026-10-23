#!/usr/bin/env python3
"""Export the generated 5x6 Halloween atlas and scaffold 30 independent puzzles."""
import argparse,copy,json,tempfile
from pathlib import Path
import numpy as np
from scipy.ndimage import label,find_objects,center_of_mass,binary_dilation
from PIL import Image
from prepare_watermill_chapter import export
from catalog_json import dumps_catalog
NAMES=['Autumn foundation','Manor facade','Timber gable','Purple slate roof','Stone tower','Tower roof','Chimney','Carved door','Gothic window','Autumn balcony','Entrance stairs','Iron gate','Twisted tree','Autumn canopy','Jack-o-lantern','Friendly ghost','Black bat','Witch hat','Potion cauldron','Witch broom','Spellbook','Amber lantern','Headstone','Black cat','Candles','Spider medallion','Purple crystals','Candy bowl','Owl','Skull and mushrooms']

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('atlas',type=Path);args=ap.parse_args()
    destination=Path('Backend/ContentSource/Artwork/Halloween 2026')
    if destination.exists():raise FileExistsError('Preserve the existing event assets rather than overwrite')
    image=Image.open(args.atlas).convert('RGBA');alpha=np.array(image.getchannel('A'))
    labels,_=label(alpha>=64);regions=find_objects(labels);counts=np.bincount(labels.ravel());slots={}
    for region in np.argsort(counts[1:])[::-1]+1:
        cy,cx=center_of_mass(alpha>=64,labels,int(region))
        slot=min(5,int(cy*6/image.height))*5+min(4,int(cx*5/image.width))
        if slot not in slots:slots[slot]=int(region)
        if len(slots)==30:break
    if len(slots)!=30:raise ValueError('Atlas must contain thirty separate sprites')
    with tempfile.TemporaryDirectory(prefix='.halloween-assets-',dir='ArrowGate') as temp:
        root=Path(temp)/destination.name;root.mkdir()
        (root/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}},indent=2)+'\n')
        for i in range(30):
            region=slots[i];ys,xs=regions[region-1]
            if counts[region]<300:raise ValueError(f'Object {i+1} is missing or fragmented')
            bounds=(max(0,xs.start-3),max(0,ys.start-3),min(image.width,xs.stop+3),min(image.height,ys.stop+3))
            tile=image.crop(bounds);keep=binary_dilation(labels[bounds[1]:bounds[3],bounds[0]:bounds[2]]==region,iterations=3)
            a=np.array(tile.getchannel('A'));a[~keep]=0;tile.putalpha(Image.fromarray(a))
            export(root,f'HalloweenManorPiece{i+1:02d}',tile)
        export(root,'HalloweenManorComplete',Image.open('Design/Events/Halloween2026/halloween-complete.png').convert('RGBA'))
        root.rename(destination)
    source=json.loads(Path('Backend/ContentSource/Levels/chapter-01.json').read_text())['levels'][24]
    levels=[]
    for i in range(30):
        level=copy.deepcopy(source)
        level.update(id=10001+i,chapterID=0,difficulty='nightmare',timeLimit=0,completionArtwork=f'HalloweenManorPiece{i+1:02d}',rewardName='Halloween · '+NAMES[i])
        level.pop('completionReward',None);level.pop('rewardEmoji',None)
        levels.append(level)
    Path('Design/Events/Halloween2026/halloween-puzzles.json').write_text(dumps_catalog({'levels':levels})+'\n')
    print('Exported 30 Halloween pieces and the complete manor; puzzle scaffold ready.')

if __name__=='__main__':main()
