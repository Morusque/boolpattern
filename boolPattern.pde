
Pattern[] pat = new Pattern[3];
PImage baseIm;

String baseName = "photo07.jpg";

void setup() {
  baseIm=loadImage(baseName);
  size(baseIm.width, baseIm.height);
  generate();
  drawOnScreen();
  save(baseName+"B.png");
}

void draw() {
  /*
  for (int i=0; i<3; i++) pat[i].evolve();
   drawOnScreen();
   */
}

void drawOnScreen() {
  PGraphics[] layers = new PGraphics[3];
  for (int i=0; i<3; i++) {
    layers[i]=createGraphics(width, height, JAVA2D);
    layers[i].beginDraw();
    pat[i].draw(layers[i], 0, 0, width, height);
    layers[i].endDraw();
  }
  for (int x=0; x<baseIm.width; x++) {
    for (int y=0; y<baseIm.height; y++) {
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
  Pattern(int level, PImage base) {
    w=3;
    h=3;
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
    for (int x=0; x<w; x++) {
      for (int y=0; y<h; y++) {
        p[x][y]=false;
        if (brightness(resized.get(x, y))>density*0x100) p[x][y]=true;
      }
    }
    /*
    int converted=0;
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
     */
  }
  void draw(PGraphics l, float xD, float yD, float wD, float hD) {
    l.noStroke();
    for (int x=0; x<w; x++) {
      for (int y=0; y<h; y++) {
        if (wD/(float)w<=1&&hD/(float)h<=1) {
          l.fill((float)(density*0x100));
          /*
          if (p[x][y]) l.fill((float)(density*0x100)+(float)(0x100-density)*0x01);
           else l.fill((float)(density*0x100)-(float)(density)*0x01);
           */
          l.rect(xD, yD, wD, hD);
        } else {
          if (tP==null||fP==null) {
            PVector chunkDimensions = new PVector((float)base.width/w, (float)base.height/h);
            PImage croppedT = base.get(floor(floor((float)w/2.0f)*chunkDimensions.x), floor(floor((float)h/2.0f)*chunkDimensions.y), ceil(chunkDimensions.x), ceil(chunkDimensions.y));
            PImage croppedF = base.get(floor(floor((float)w/2.0f)*chunkDimensions.x), floor(floor((float)h/2.0f)*chunkDimensions.y), ceil(chunkDimensions.x), ceil(chunkDimensions.y)); 
            int lerpsDoneT=0;
            int lerpsDoneF=0;
            for (int x2=0; x2<w; x2++) {
              for (int y2=0; y2<h; y2++) {
                PImage thisCrop = base.get(floor(floor((float)x2)*chunkDimensions.x), floor(floor((float)y2)*chunkDimensions.y), ceil(chunkDimensions.x), ceil(chunkDimensions.y));
                if (p[x2][y2]) {
                  for (int x3=0; x3<thisCrop.width; x3++) {
                    for (int y3=0; y3<thisCrop.height; y3++) {
                      croppedT.set(x3, y3, lerpColor(thisCrop.get(x3, y3), croppedT.get(x3, y3), 1.0f/(lerpsDoneT)));
                    }
                  }
                  lerpsDoneT++;
                } else {
                  for (int x3=0; x3<thisCrop.width; x3++) {
                    for (int y3=0; y3<thisCrop.height; y3++) {
                      croppedF.set(x3, y3, lerpColor(thisCrop.get(x3, y3), croppedF.get(x3, y3), 1.0f/(lerpsDoneF)));
                    }
                  }
                  lerpsDoneF++;
                }
              }
            }
            tP = new Pattern(level+1, croppedT);
            fP = new Pattern(level+1, croppedF);
          }
          if (p[x][y]) tP.draw(l, xD+wD*x/w, yD+hD*y/h, wD/w, hD/h);
          else fP.draw(l, xD+wD*x/w, yD+hD*y/h, wD/w, hD/h);
        }
      }
    }
  }
  void evolve() {
    int x=floor(random(w));
    int y=floor(random(h));
    if (random(1)<0.5f) p[x][y]^=true;
    if (tP!=null) tP.evolve();
    if (fP!=null) fP.evolve();
  }
}

