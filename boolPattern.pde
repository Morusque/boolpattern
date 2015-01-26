
Pattern[] pat = new Pattern[3];
PImage baseIm;

// PARAMETERS :
boolean compress=false;// true to compress (png->bpc), false to uncompress (bpc->png)
String baseName = "photo23.jpg.bpc";// i.e. photo.bpc or photo.jpg
short patternSubdivisions = 3;// number of raws/columns in a pattern
float compressionAmount = 3;// prior downscaling
int densityMode = 0;// 0 = uses average value as a threshold, 1 = repartition according to density
boolean stopIfSolid=true;// stop subdividing if a pattern is solid
boolean favorHighestDimension=false;// reduce one of the dimensions (export does not work yet but preview does)

void setup() {
  frame.setResizable(true);
  if (compress) compress();
  else uncompress();
}

void draw() {
  drawOnScreen();
}

void uncompress() {
  byte[] bInput = loadBytes(baseName);
  ArrayList<Boolean> bitsA = new ArrayList<Boolean>();
  for (int i=0; i<bInput.length; i++) {
    for (int j=0; j<8; j++) bitsA.add((((bInput[i]>>(7-j))&0x01)==0x01));
  }
  // for (int i=0; i<bitsA.size (); i++) print(bitsA.get(i)?"1":"0"); 
  patternSubdivisions=0;
  while (bitsA.remove (0)) patternSubdivisions++;
  for (int currentLayer=0; currentLayer<3; currentLayer++) {
    pat[currentLayer]=new Pattern(0);
    if (!bitsA.remove(0)) {
      pat[currentLayer].feed(bitsA);
    } else {
      pat[currentLayer]=pat[currentLayer-1];
    }
  }
  drawOnScreen();
  save(baseName+"B.png");
}

void compress() {
  baseIm=loadImage(baseName);
  size(baseIm.width, baseIm.height);

  frame.setResizable(true);

  generate();
  drawOnScreen();

  ArrayList<Boolean> bitsA = new ArrayList<Boolean>();

  for (int i=0; i<patternSubdivisions; i++) bitsA.add(true);
  bitsA.add(false);

  boolean[] oldD = new boolean[0];// TODO if "favorHighestDimension" is on, add informations about it
  for (int l=0; l<3; l++) {
    boolean[] d = pat[l].export();
    boolean same=true;
    if (l>0) {
      if (oldD.length!=d.length) {
        same=false;
      } else {
        for (int i=0; i<d.length; i++) if (d[i]!=oldD[i]) same=false;
      }
    } else {
      same=false;
    }
    oldD = new boolean[d.length];
    for (int i=0; i<d.length; i++) oldD[i]=d[i];
    bitsA.add(same);
    if (!same) {
      for (int i=0; i<d.length; i++) {
        bitsA.add(d[i]);
      }
    }
  }
  for (int i=0; i<bitsA.size (); i++) {
    if (bitsA.get(i)) print("1");
    else print("0");
  }
  byte[] bytes = new byte[ceil((float)bitsA.size()/8)];
  for (int i=0; i<bytes.length; i++) {
    bytes[i]=0;
    for (int j=0; j<8; j++) {
      if (i*8+j<bitsA.size()) if (bitsA.get(i*8+j)) bytes[i]+=1<<(7-j);
    }
  }  
  saveBytes(baseName+".bpc", bytes);

  save(baseName+"B.png");
}

void drawOnScreen() {
  PGraphics[] layers = new PGraphics[3];
  for (int i=0; i<3; i++) {
    layers[i]=createGraphics(width, height, JAVA2D);
    layers[i].beginDraw();
    pat[i].draw(layers[i], 0, 0, width, height);
    layers[i].endDraw();
  }
  for (int x=0; x<width; x++) {
    for (int y=0; y<height; y++) {
      stroke(brightness(layers[0].get(x, y)), brightness(layers[1].get(x, y)), brightness(layers[2].get(x, y)));
      point(x, y);
    }
  }
}

void generate() {
  PImage rLayer = createImage(baseIm.width, baseIm.height, RGB);
  PImage gLayer = createImage(baseIm.width, baseIm.height, RGB);
  PImage bLayer = createImage(baseIm.width, baseIm.height, RGB);
  for (int x=0; x<baseIm.width; x++) {
    for (int y=0; y<baseIm.height; y++) {
      color c = baseIm.get(x, y);
      rLayer.set(x, y, color(floor(red(c)), floor(red(c)), floor(red(c))));
      gLayer.set(x, y, color(floor(green(c)), floor(green(c)), floor(green(c))));
      bLayer.set(x, y, color(floor(blue(c)), floor(blue(c)), floor(blue(c))));
    }
  }
  pat[0] = new Pattern(0, rLayer);
  pat[1] = new Pattern(0, gLayer);
  pat[2] = new Pattern(0, bLayer);
  for (int i=0; i<3; i++) pat[i].propagateFor((float)width/compressionAmount, (float)height/compressionAmount);
}

void keyPressed() {
  generate();
}

class Pattern {
  int w;
  int h;
  boolean[][] p;
  double density;
  Pattern tP;
  Pattern fP;
  int level;
  PImage base;
  Pattern(int level) {
    w=patternSubdivisions;
    h=patternSubdivisions;
    p = new boolean[w][h];
    this.level=level;
  }  
  Pattern(int level, PImage base) {
    w=patternSubdivisions;
    h=patternSubdivisions;
    if (favorHighestDimension) {
      if (base.width>base.height) h--;
      else w--;
    }
    p = new boolean[w][h];
    this.level=level;
    this.base=base;
    PImage resized = base.get();
    resized.resize(w, h);
    this.density=0;    
    for (int x=0; x<base.width; x++) {
      for (int y=0; y<base.height; y++) {
        color c = base.get(x, y);
        density+=brightness(c);
      }
    }
    density/=(double)base.width*base.height*0x100;
    int converted=0;
    if (densityMode==0) {
      for (int x=0; x<w; x++) {
        for (int y=0; y<h; y++) {
          p[x][y]=false;
          if (brightness(resized.get(x, y))>density*0x100) {
            p[x][y]=true;
            converted++;
          }
        }
      }
    }
    if (densityMode==1) {
      while (converted<density* (w*h)) {
        int bestX=-1;
        int bestY=-1;
        float bestBrightness=-1;
        for (int x=0; x<w; x++) {
          for (int y=0; y<h; y++) {
            if (!p[x][y]) {
              float thisBrightness = brightness(resized.get(x, y));
              if (bestBrightness==-1||thisBrightness>=bestBrightness) {
                bestBrightness=thisBrightness;
                bestX=x;
                bestY=y;
              }
            }
          }
        }
        if (bestBrightness!=-1) p[bestX][bestY]=true;
        converted++;
      }
    }
  }
  void propagateFor(float wD, float hD) {
    if (wD/(float)w>1||hD/(float)h>1) {
      PVector chunkDimensions = new PVector((float)base.width/w, (float)base.height/h);
      PImage croppedT = base.get(floor(floor((float)w/2.0f)*chunkDimensions.x), floor(floor((float)h/2.0f)*chunkDimensions.y), ceil(chunkDimensions.x), ceil(chunkDimensions.y));
      PImage croppedF = base.get(floor(floor((float)w/2.0f)*chunkDimensions.x), floor(floor((float)h/2.0f)*chunkDimensions.y), ceil(chunkDimensions.x), ceil(chunkDimensions.y)); 
      int lerpsDoneT=0;
      int lerpsDoneF=0;
      for (int x2=0; x2<w; x2++) {
        for (int y2=0; y2<h; y2++) {
          PImage thisCrop = base.get(floor(floor((float)x2)*chunkDimensions.x), floor(floor((float)y2)*chunkDimensions.y), ceil(chunkDimensions.x), ceil(chunkDimensions.y));
          if (p[x2][y2]) {
            lerpsDoneT++;
            for (int x3=0; x3<thisCrop.width; x3++) {
              for (int y3=0; y3<thisCrop.height; y3++) {
                croppedT.set(x3, y3, lerpColor(thisCrop.get(x3, y3), croppedT.get(x3, y3), 1.0f/(lerpsDoneT)));
              }
            }
          } else {
            lerpsDoneF++;
            for (int x3=0; x3<thisCrop.width; x3++) {
              for (int y3=0; y3<thisCrop.height; y3++) {
                croppedF.set(x3, y3, lerpColor(thisCrop.get(x3, y3), croppedF.get(x3, y3), 1.0f/(lerpsDoneF)));
              }
            }
          }
        }
      }
      tP = new Pattern(level+1, croppedT);
      fP = new Pattern(level+1, croppedF);
      if (tP.isSolid()&&stopIfSolid) {
        tP=null;
      } else {
        tP.propagateFor(wD/(float)w, hD/(float)h);
      }
      if (fP.isSolid()&&stopIfSolid) {
        fP=null;
      } else {
        fP.propagateFor(wD/(float)w, hD/(float)h);
      }
    }
  }
  boolean isSolid() {
    boolean last=false;
    for (int x=0; x<w; x++) {
      for (int y=0; y<h; y++) {
        if (x>0||y>0) {
          if (p[x][y]!=last) return false;
        }
        last=p[x][y];
      }
    }
    return true;
  }
  void draw(PGraphics l, float xD, float yD, float wD, float hD) {
    l.noStroke();
    for (int x=0; x<w; x++) {
      for (int y=0; y<h; y++) {
        if (tP!=null&&fP!=null) {
          if (p[x][y]) tP.draw(l, xD+wD*(float)x/w, yD+hD*(float)y/h, wD/(float)w, hD/(float)h);
          else fP.draw(l, xD+wD*(float)x/w, yD+hD*(float)y/h, wD/(float)w, hD/(float)h);
        } else {
          l.fill((float)(density*0x100));
          l.rect(xD, yD, wD, hD);
        }
      }
    }
  }
  void evolve() {
    int x=floor(random(w));
    int y=floor(random(h));
    if (random(1)<0.2f) {
      p[x][y]^=true;
    } else {
      if (tP!=null) tP.evolve();
      if (fP!=null) fP.evolve();
    }
  }
  boolean[] export() {
    ArrayList<Boolean> data = new ArrayList<Boolean>();
    for (int x2=0; x2<w; x2++) {
      for (int y2=0; y2<h; y2++) {
        data.add(p[x2][y2]);
      }
    }
    if (tP!=null) {
      boolean[] dataT = tP.export();
      data.add(true);
      for (int i=0; i<dataT.length; i++) data.add(dataT[i]);
    } else {
      data.add(false);
    }
    if (fP!=null) {
      data.add(true);
      boolean[] dataF = fP.export();
      for (int i=0; i<dataF.length; i++) data.add(dataF[i]);
    } else {
      data.add(false);
    }
    boolean[] dataR = new boolean[data.size()];
    for (int i=0; i<dataR.length; i++) dataR[i] = data.get(i);
    return dataR;
  }
  void feed(ArrayList<Boolean> bits) {
    density=0;
    for (int x2=0; x2<w; x2++) {
      for (int y2=0; y2<h; y2++) {
        p[x2][y2] = bits.remove(0);
        density+=p[x2][y2]?1:0;
      }
    }
    density/=w*h;
    if (bits.remove(0)) {
      tP=new Pattern(level+1);
      tP.feed(bits);
    }
    if (bits.remove(0)) {
      fP=new Pattern(level+1);
      fP.feed(bits);
    }
  }
}

