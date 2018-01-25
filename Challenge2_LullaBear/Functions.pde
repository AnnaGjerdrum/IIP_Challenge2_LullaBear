void weightChange(boolean up, int actionIndex) {

  //boolean if you go up = true, down = false. actionIndex = the index of current lullaby.
  //dont want to substract below 1
  //dont want to increase above 100

  // if up = true, 
  

  if (up) {
    
    //println("Up is true");
    
    int improved = weight.length;
    
    println(improved);
    for (int i = 0; i < weight.length; i++) {
      if (weight[i] <= 1) {
        improved = improved - 1;
      } else {
        weight[i] = weight[i] - 1;
      }
    }
    
    //println("w: " + weight[actionIndex]);

    weight[actionIndex] = weight[actionIndex] + improved;
    
    //println("w: " + weight[actionIndex]);
    
  } else {

    //println("up is false");  
    
    int demoted = weight.length;

    if (weight[actionIndex] > demoted) {

      for (int i = 0; i < weight.length; i++) {
        weight[i] = weight[i] + 1;
      }
      
      weight[actionIndex] = int(weight[actionIndex] - demoted);
      
    } else {

      int canAdd = weight[actionIndex] - 1;
      //System.out.println("CanAdd: " + canAdd);
      ArrayList<Integer> smallest = new ArrayList<Integer>(); 

      smallest.add(weight[0]);

      for (int i = 1; i < weight.length; i++) {
        
        for (int k = 0; k < smallest.size(); k++) {
          if (smallest.get(k) > weight[i]) {
            smallest.add(k, i);
            break;
          } else if (k == smallest.size()-1) {
            smallest.add(k+1, i);
          }
        }
      }

      for (int i = 0; i < canAdd; i++) {
        weight[smallest.get(i)] = weight[smallest.get(i)] + 1;
      }

      weight[actionIndex] = weight[actionIndex] - canAdd;
    }
  }
  
  println("weights: ");
  for (int i = 0; i < weight.length; i++) {  
    print(" - " + i + ": " + weight[i]);
  }
  
  
  println();
  println();
}



//Tool functions

//Append a value to a float[] array.
float[] appendArray (float[] _array, float _val) {
  float[] array = _array;
  float[] tempArray = new float[_array.length-1];
  arrayCopy(array, tempArray, tempArray.length);
  array[0] = _val;
  arrayCopy(tempArray, 0, array, 1, tempArray.length);
  return array;
}

// i = index of sound file
// visualIndex = distance from x * width/(data.length + 1);
void drawPlayButtons(int i, int visualIndex, int visualLength, boolean green) {
 
  int lengthBetween = width/visualLength + 1;
  
  pushStyle();
  rectMode(CENTER);
  noStroke();
  fill(150, 150, 150);
  rect(lengthBetween*visualIndex, 8*height/10, 3, 142);
  noStroke();
  if (green) {
    fill(0, 255, 0);
  } else {
    fill(255, 102, 0);
  }
  ellipse(lengthBetween*visualIndex, 8*height/10 - h, w, h);  // Restore original style
  
  popStyle();
}

void lineGraph(float[] data) {
  
  pushStyle();
  beginShape();
  
  fill(220, 255, 255);
  stroke(color(0, 255, 255));
  strokeWeight(3);
 
  int lengthBetween = width/(data.length + 1);
 
  vertex(0, 9 * height/10);
 
  for (int i = 0; i < data.length; i++) {
    if (data[i] != 0) {
      vertex(lengthBetween * i+1, (9 * height/10) - (data[i] * 4));
    }
  }
  
  vertex(width, 9*height/10);
  
  endShape(CLOSE);
  popStyle();
}

//Draw a line graph to visualize the sensor stream
void lineGraphOrig(float[] data, float _l, float _u, float _x, float _y, float _w, float _h, int _index) {
  color colors[] = {
    color(255, 0, 0), color(0, 255, 0), color(0, 0, 255), color(255, 255, 0), color(0, 255, 255), 
    color(255, 0, 255), color(0)
  };
  int index = min(max(_index, 0), colors.length);
  pushStyle();
  float delta = _w/data.length;
  beginShape();
  noFill();
  stroke(colors[index]);
  for (float i : data) {
    float h = map(i, _l, _u, 0, _h);
    vertex(_x, _y+h);
    _x = _x + delta;
  }
  endShape();
  popStyle();
}

//Draw a bar graph to visualize the modeArray
void barGraph(float[] data, float _l, float _u, float _x, float _y, float _w, float _h) {
  color colors[] = {
    color(175, 250, 254), color(175, 250, 254), color(255, 182, 0), color(152, 64, 103), color(244, 208, 63), 
    color(242, 121, 53), color(0, 121, 53), color(128, 128, 0), color(52, 0, 128), color(128, 52, 0)
  };
  pushStyle();
  noStroke();
  float delta = _w / data.length;
  for (int p = 0; p < data.length; p++) {
    float i = data[p];
    int cIndex = min((int) i, colors.length-1);
    if (i<0) fill(255, 255);
    else fill(colors[cIndex], 255);
    float h = map(_u, _l, _u, 0, _h);
    rect(_x, _y-h, delta, h);
    _x = _x + delta;
  }
  popStyle();
}

int sumArray(int[] array) {
  int sum = 0;

  for (int i = 0; i < array.length; i++) {
    sum += array[i];
  }

  return sum;
}