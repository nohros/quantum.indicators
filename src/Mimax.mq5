//+------------------------------------------------------------------+
//|                                                      Minimax.mq5 |
//|                                       Copyright 2018, Nohros Inc |
//|                                           https://www.nohros.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Nohros Inc"
#property link      "https://www.nohros.com"
#property version   "1.00"
#property indicator_chart_window

#property indicator_buffers 8
#property indicator_plots   8

#property indicator_label1  "Sell"
#property indicator_type1   DRAW_NONE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "Buy"
#property indicator_type2   DRAW_NONE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_label3  "UpBand"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow

#property indicator_label4  "DownBand"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrAqua

#property indicator_label5  "Min"
#property indicator_type5   DRAW_NONE
#property indicator_color5  Blue

#property indicator_label6  "Max"
#property indicator_type6   DRAW_NONE
#property indicator_color6  Red

#property indicator_label7  "UpOffset"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrYellow
#property indicator_style7  STYLE_DOT

#property indicator_label8  "DownOffset"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrAqua
#property indicator_style8  STYLE_DOT

double input trigger_ = 780; // Distance
double input delta_ = 100; // Offset
int input holding_ = 3; // Holding
int input mode_ = 0; // (0: Percentage, 1: Point)

double sell_[];
double buy_[];

double up_band_[];
double down_band_[];

double min_[];
double max_[];

double up_offset_[];
double down_offset_[];

int OnInit() {
   SetIndexBuffer(0, sell_, INDICATOR_DATA);
   SetIndexBuffer(1, buy_, INDICATOR_DATA);
   SetIndexBuffer(2, up_band_,INDICATOR_DATA);
   SetIndexBuffer(3, down_band_,INDICATOR_DATA);
   
   SetIndexBuffer(4, min_,INDICATOR_DATA);
   SetIndexBuffer(5, max_,INDICATOR_DATA);
   
   SetIndexBuffer(6, up_offset_,INDICATOR_DATA);
   SetIndexBuffer(7, down_offset_,INDICATOR_DATA);
 
   IndicatorSetString(INDICATOR_SHORTNAME,"Mimax-("+string(trigger_)+")");
   
   ArrayInitialize(sell_, 0.0);
   ArrayInitialize(buy_, 0.0);
   ArrayInitialize(up_band_, 0.0);
   ArrayInitialize(down_band_, 0.0);
   ArrayInitialize(min_, 0.0);
   ArrayInitialize(max_, 0.0);
   
   ArrayInitialize(up_offset_, 0.0);
   ArrayInitialize(down_offset_, 0.0);
            
   return(INIT_SUCCEEDED);
}

int OnCalculate(
   const int rates_total,
   const int prev_calculated,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const long &volume[],
   const int &spread[]) {
    
   if (IsStopped()) {
     return(0);
   }
 
   int start=MathMax(0, prev_calculated-1);
   for (int i = start; i < rates_total; ++i) { 
     if (i < 2) {
       continue;
     }
     
     // The min/max values should be reset at each new day
     ResetOnNewDay(time, i);
          
     if (min_[i-1] == 0 && max_[i-1] == 0) {
       min_[i-1] = min_[i] = low[i];
       max_[i-1] = max_[i] = high[i];
       buy_[i-1] = buy_[i] = 0;
       sell_[i-1] = sell_[i] = 0;
     }
     
     // If the current min is lesser than the previous
     // we have a new min
     if (low[i] < min_[i-1]) {
       min_[i] = low[i];
     } else {
       min_[i] = min_[i-1];
     }
     
     // If the current max is greater than the previous
     // we have a new max
     if (high[i] > max_[i-1]) {
       max_[i] = high[i];
       //direction_[i] = POSITION_TYPE_SELL;
     } else {
       max_[i] = max_[i-1];
       //direction_[i] = direction_[i-1];
     }

     if (mode_ == 0) {
       up_band_[i] = min_[i] *(1+trigger_);
       down_band_[i] = max_[i] *(1-trigger_);
     } else if (mode_ == 1) {
       up_band_[i] = min_[i] + trigger_;
       down_band_[i] = max_[i] - trigger_;
     }
          
     up_offset_[i] = up_band_[i] - delta_;
     down_offset_[i] = down_band_[i] + delta_;

     SetSignal(i, open, high, low, close);
     
     HoldSignal(i);
   }
    
   return(rates_total);
}

void SetSignal(const int i,
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[]) {

  buy_[i] = 0.0;
  sell_[i] = 0.0;
  
  if (down_band_[i] >= up_band_[i]) {
    return;
  }
  
  if (low[i] < down_offset_[i]) {
    buy_[i] = low[i];
    sell_[i] = 0.0;
  } else if (high[i] > up_offset_[i]) {
    sell_[i] = high[i];
    buy_[i] = 0.0;
  }
}

void HoldSignal(const int i) {
  if (holding_ > 0 && i > holding_) {
    if (buy_[i-1] > 0.0 && buy_[i-holding_] == 0.0) {
      buy_[i] = buy_[i-1];
      return;
    }

    if (sell_[i-1] > 0.0 && sell_[i-holding_] == 0.0) {
      sell_[i] = sell_[i-1];
      return;
    }
  }
}

void ResetOnNewDay(const datetime &time[], int i) {
  if (i < 2) {
    return;
  }
  
  MqlDateTime previous, now;
  TimeToStruct(time[i-1], previous);
  TimeToStruct(time[i], now);
  
  if (previous.day != now.day) {
    max_[i] = min_[i] = 0;
    max_[i-1] = min_[i-1] = 0;
    buy_[i] = 0.0;
    sell_[i] = 0.0;
  }
}
