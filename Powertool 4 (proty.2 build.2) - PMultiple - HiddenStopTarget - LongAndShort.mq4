//+-------------------------------------------------------------------------------------------------+
//|                 Powertool 4 (proty.2 build.2) - PMultiple - HiddenStopTarget - LongAndShort.mq4 |
//|                                                                        Copyright 2017, AMT Corp |
//|                                                                                 www.AMTCorp.com |
//+-------------------------------------------------------------------------------------------------+
#property copyright "Copyright 2016, AMT Corp"
#property link      "www.AMTCorp.com"
#property version   "1.00"
#property strict
#property description "PowerTool 4 - Triple Timeframes PMultiple - Build.2"




/*
Version: proty.2 build.2
2017.05.20 (0549) - Saturday
"Powertool 4 (proty.2 build.2) - PMultiple - HiddenStopTarget - LongAndShort.mq4"

adding:
- MTF Setup Explicit variable
- Marker for HTF Setup and MTF setup on M5 trigger screenn

So that, on M5, all setup has EXPLICIT variable to process the logic.
The logic must NOT be embedded in if(...) clause, because that logic is not transparent.

Changes made:

Exercise: AUDJPY

- Bollinger Band on M5: Parameters:
  Now: BB( 30 , 0.9 , PRICE_CLOSE ) ; Previous:BB( 36 , 1.0 , PRICE_TYPICAL )

- MTF SETUP
  H1 Overbought Oversold Flag
  Now: RSI(4 , Close) ; Previous: RSI(6 , Close)
  Now: a window of 4 HOURS oversold and NO overbought in the past 1-2 hours for LONG
   and a window of 4 hours overbought and NO oversold in the past 1-2 hours of SHORT

- LTF MARKER
  on M5, HTF Setup Marker appears when HTF setup is true
  on M5, MTF Setup Marker appears when MTF setup is true


Identified:

- Exit target is far above the resistance of weekly and monthly, profit goes well , then
  fall back, resulting overall trade to negative 30%

  With exit is set to target monthly resistance, profit turned 100+% in a few weeks !!
  Meanings: pyramiding works, entry works, only exit needs better method:
  - to allow room for large trend to move, and
  - to keep trades falling from 100% return down to -30%.

- Entry is late on 800+ pips within leg of the year;
  targeting with 75percentile of 1600 pips for AUDJPY means start at half leg already.

  https://1drv.ms/u/s!ArML2FzV08i1g587wIdZr_giZZtyNQ


- Break even stop has 0.0 pips buffer for slippage; means actual break even stop will
  lose 5-10 pips!


To resolve:

- Adding threshold-ed weekly trailing stop after profit 60% of leg of the year

- Ability to amend position's target profit (hidden target) once trade has been entered to
  suit VHTF (very high time frame) ; monthly or weekly major resistance.

  The robot must be able to store every single position's stop, target, trailing stop,
  pyramid sequence #, position's ticket, etc.
  We call this "position's parameters".

  So that, when the robot down, then reboot, the robot must be able to pick up the trade
  and its original parameters to exit, to pyramid, to continue or to stop pyramiding, etc.

Marks: 2017.05.21 (2327) - Sunday





Version: proty.2 build.1
"Powertool 4 (proty.2 build.1) - PMultiple - HiddenStopTarget - LongAndShort.mq4"

add 1:
- Short selling mirroring from long-only trade


Version build.2
"Powertool 4 (build.2) PMultiple - Hidden_Stop_And_Target.mq4"
- Build.1 features PLUS

add 3:
  - Reporting Equity
    - Total Lots

add 2:
  - Reporting Equity

add 1:
  - Hidden Stop
  - Hidden Target

Version build.1 PMultiple
"Powertool 4 (build.1) PMultiple.mq4"
- Simplified process
  - Execute_Entry_Buy_PMultiple()
  - Breakeven
*/


/*
    * The core code is based on [MVTS_4_HFLF_Model_A.mq4]

    * PowerTool 4 attempts to trade "Leg of The Year" trend, i.e.,
      weekly drift that makes the maximum range of the year.

    * Thence, one application of robot is on one trend leg

*/

/*
  Find line with tag "TODO" for pending work
*/

/*
Trial commit
*/

//+-------------------------------------------------------------------------------------------------+
//| INSERT GENERIC REUSABLE FUNCTIONS                                                               |
//+-------------------------------------------------------------------------------------------------+

#include <PowerToolIncludes.mqh>



//+-------------------------------------------------------------------------------------------------+
//| DEFINITIONS                                                                                     |
//+-------------------------------------------------------------------------------------------------+

#define   _DAYSECONDS_ 86400  // 1day = 24hr * 60min * 60sec = 86400sec


struct    SLTPstruct
{
    int       Ticket            ;
    int       PositionSequence  ;
    double    openPrice         ;
    double    SL                ;
    double    TP                ;
    datetime  openTime          ;
    int       magicNumber       ;
    bool      MarkedToClose     ;
};

/*
sat19feb17
Rooting out the code to bare skeleton. Remove all non-core elements.
Use [MVTS_4_HFLF_Model_A.mq4] as master ; I can copy back everything into this code.

          ******** Non-core elements should go to PowerToolIncludes.mqh ********

*/




//+-------------------------------------------------------------------------------------------------+
//| SYSTEM NAMING AND FILE NAMING                                                                   |
//+-------------------------------------------------------------------------------------------------+

string  SystemName      = "Powertool 4 HTF-MTF-LTF on Weekly Trend PMultiple" ;
string  SystemShortName = "Powertool 4 PM";
string  SystemNameCode  = "PT4PM";
string  VersionSeries   = "1.00" ;
//-- string  VersionDate     = "(sun19feb17)" ;
string  VersionDate     = "(sun19mar17)" ;



//+-------------------------------------------------------------------------------------------------+
//| ENUMERATION                                                                                     |
//+-------------------------------------------------------------------------------------------------+

enum ENUM_STRATEGY_TREND
{
  STRATEGY_MEDIUMTREND_WEEKLY_LARGE_RANGE  ,
  STRATEGY_LONGTREND_LEG_OF_THE_YEAR
};



enum ENUM_TRADEDIRECTION
  {
    DIR_BUY,
    DIR_SELL
  };


enum ENUM_TRADING_MODE
  {
    TM_LONG    ,
    TM_SHORT
  };






    //-- Hendy Notes:
    //-- This is what awesomeness with Powertool 4 application. At one application, you can only
    //-- long only, or short only application despite HTF direction.
    //-- The Weekly Drift determines the direction of the trade !




//+-------------------------------------------------------------------------------------------------+
//| SYSTEM INTERNAL PARAMETERS                                                                      |
//+-------------------------------------------------------------------------------------------------+

int   PERIOD_TTF = PERIOD_W1 ;
int   PERIOD_HTF = PERIOD_D1 ;
int   PERIOD_MTF = PERIOD_H1 ;
int   PERIOD_LTF = PERIOD_M5 ;


//+-------------------------------------------------------------------------------------------------+
//| EXTERNAL PARAMETERS FOR OPTIMIZATION                                                            |
//+-------------------------------------------------------------------------------------------------+



extern  string      Header1                   =
                                        "------------------ Trading Controller -------------------" ;
extern  ENUM_TRADING_MODE
                    TradeMode                 = TM_LONG  ;

extern  ENUM_STRATEGY_TREND
                    Strategy_Trend            = STRATEGY_MEDIUMTREND_WEEKLY_LARGE_RANGE ;



extern  string      Header1a                  =
                                        "----------- Strategy Medium Exit Target Price ------------" ;
extern  double      TargetPriceMediumTrend    = 106.52 ;
// You set up TargetPriceMediumTrend based on Support / Resistance, or Fibonacci method
// The price near the tip of the previous resistance or support


extern  string      Header1b                  =
                                        "- Base Price Where Range Starts or Leg Of The Year Starts -" ;
extern  double      BasePriceLongTrend                 = 86.12 ;
// You set the BasePriceLongTrend using Support / Resistance that defines
// the base of Leg of the Year or the Large Weekly Range



extern  string      Header2                   =
                                        "------------------ Entry Counter in a Day ----------------" ;

extern  int         DailyEntryMax             = 2 ;

extern  string      Header3                   =
                                        "--------------------- Risk Controller -------------------" ;
extern  double      RiskPerTrade              = 0.01    ;
extern  double      NATR                      = 5.0     ;
extern  double      CapOnStopDistancePips     = 25.0    ;
extern  bool        RiskBooster               = false   ;



extern  string      Header4                   =
                                        "--------- Stop Loss, Breakeven, Profit Locking ----------" ;
extern  bool        HiddenStopLossTarget      = true  ;
extern  bool        BreakEvenStop_Apply       = true  ;
extern  bool        ProfitLock250pips_Apply   = true  ;

extern  string      Header5                   =
                                        "--------------------- Pyramiding  -----------------------" ;
extern  int         MaxPositions              = 6     ;

extern  string      Header6                   =
                                        "------------------- Exclusion Zone ----------------------" ;
extern  string      ExclZone_Date             = "2016.06.24"  ;
extern  string      ExclZone_Currency         = "GBP"         ;


        //int         TakeProfit                ;       //-- in pips



//+-------------------------------------------------------------------------------------------------+
//| EXCLUSION_IN_ADVANCE ZONE                                                                       |
//+-------------------------------------------------------------------------------------------------+

int     ExclZone_DayBefore  = 1     ;
int     ExclZone_DayAfter   = 1     ;
bool    ExclZone_In         = false ;


//+-------------------------------------------------------------------------------------------------+
//| EXCLUSION LATE SIGNAL IN A TREND                                                                |
//+-------------------------------------------------------------------------------------------------+

int     EntrySignalCountBuy = 0   ;
int     EntrySignalCountSell = 0  ;

int     EntrySignalCountThreshold = 250 ;

//      New trend happens on new analysis of weekly trend in attempt to trade leg of the year
//      Signal is counted over the course of the trend



//+-------------------------------------------------------------------------------------------------+
//| DAILY LOSS LIMIT NUMBER                                                                         |
//+-------------------------------------------------------------------------------------------------+

int     DailyCountEntry  = 0 ;      //-- maximum entry times are 2 per day


//+-------------------------------------------------------------------------------------------------+
//| INTERNAL VALUE SET                                                                              |
//+-------------------------------------------------------------------------------------------------+

int     FileHandle_OHLC_Equity      = -1 ;
string  FileStringEquity_PeakAndDrawdown ;




//+-------------------------------------------------------------------------------------------------+
//| Point to Price Factor                                                                           |
//+-------------------------------------------------------------------------------------------------+

int     PointToPrice  = 1 ;




//+-------------------------------------------------------------------------------------------------+
//| TARGET PRICE ALL POSITION                                                                       |
//+-------------------------------------------------------------------------------------------------+

double   TargetPriceCommon ;


/*
IMPORTANT:
1. Run the EA on LTF or lower timeframe
2. Magic number is to pick up order if closed
3. Ask, is the code reusable for the NEXT SPRINT ?
*/



//+-------------------------------------------------------------------------------------------------+
//| THRESHOLD PRICES                                                                                |
//+-------------------------------------------------------------------------------------------------+

double    ThresholdProfitPips_LowThresh   ;
double    ThresholdProfitPips_HighThresh  ;

bool      ThresholdProfitPips_Passed      ;

// This is the price from the base. The direction of trade, Long or Short, determines the price.


//+-------------------------------------------------------------------------------------------------+
//| TRAILING STOP PRICES                                                                            |
//+-------------------------------------------------------------------------------------------------+

double    TrailingStopPrice_BUY  ;
double    TrailingStopPrice_SELL  ;

// Trailing stop variables are global, because multi parts manipulate variables: 
// 1. entry procedure initiates the variable on P1
// 2. OnTick updates the variable, and make decision when exit procedure has to happen
// This is better than using parameters cross procedure, which is confusing.


// RULE ON GLOBAL VARIABLE OR LOCAL VARIABLE:
// Anything part of the system decisioning, should be on GLOBAL VARIABLE !!
// Anything part of working on nitty gritty calculation, should be on LOCAL VARIABLE 
//    inside a procedure




//+-------------------------------------------------------------------------------------------------+
//| TRADE FLAGS                                                                                     |
//+-------------------------------------------------------------------------------------------------+

bool    TradeFlag_ProfitThresholdPassed ;
bool    TradeFlag_ClosedOnBigProfit ;




//+-------------------------------------------------------------------------------------------------+
//| BREAKEVEN MANAGEMENT                                                                            |
//+-------------------------------------------------------------------------------------------------+

//-- OnInit initiates the variables


bool    Breakeven_iPos_Applied[8] ;
        //-- Breakeven_iPos_Applied is set to 8





//+-------------------------------------------------------------------------------------------------+
//| PROFIT LOCKING MANAGEMENT                                                                       |
//+-------------------------------------------------------------------------------------------------+

//-- OnInit initiates the variables

bool    ProfitLock250Pips_iPos_Applied[8]   ;
double  ProfitLock250pips_NewStopPrice      ;



//+-------------------------------------------------------------------------------------------------+
//| HIDDEN STOP LOSS AND TARGET                                                                     |
//+-------------------------------------------------------------------------------------------------+


SLTPstruct  PositionTracker[] ;
//-- Uses the struct to hold stop loss, target





/***************************************************************************************************/
/***   BEGINNING PROGRAM   ***/
/***************************************************************************************************/



//+-------------------------------------------------------------------------------------------------+
//| Expert initialization function                                                                  |
//+-------------------------------------------------------------------------------------------------+
int OnInit()
  {

  //-- To account for 5 digit brokers
  if(Digits == 5 || Digits == 3 || Digits == 1) PointToPrice = 10 ; else PointToPrice = 1;


  //-- Reference: [MVTS_4_HFLF_Model_A.mq4] for reporting files


  //-- Initialize TradeFlag_ClosedOnBigProfit
  TradeFlag_ClosedOnBigProfit = false ;


  //-- Initialize Breakeven variables
  // Breakeven_P1_Applied  = false   ;
  // Breakeven_P2_Applied  = false   ;
  // Breakeven_P3_Applied  = false   ;
  //-- DELETE these variables if the array below works well, thus, the above become redundant


  //-- Initialize Breakeven variables
  //-- Initialize Profit Lock variables

  ArrayResize( Breakeven_iPos_Applied         , MaxPositions + 1 );
  ArrayResize( ProfitLock250Pips_iPos_Applied , MaxPositions + 1 );

  for( int i = 1 ; i <= MaxPositions ; i++ )  // Add 1 for MaxPositions
  {
    Print(  "[OnInit]:" ,
            " i: ", IntegerToString( i ) ,
            ", initializing Breakeven_iPos_Applied[i]" ,
            ", and ProfitLock250Pips_iPos_Applied[i]"
      );
    Breakeven_iPos_Applied[i]         = false ;
    ProfitLock250Pips_iPos_Applied[i] = false ;
  }


  //-- Initialize Hidden Stop and Hidden Target array
  ArrayResize( PositionTracker , MaxPositions + 1 );

  //-- Note array start from 0 to N-1
  //-- For position marking, I want consistency, position mark starts from 1 to N
  //-- Thus, the index must start from 1; ignoring index 0.
  //-- Therefore, the final index will be N; the actual array size must have N+1





  /*++  PROFIT TARGET PRICE >> STRATEGY_LONGTREND_LEG_OF_THE_YEAR ++*/
  /*-----------------------------------------------------------------------------------*/  
  // OnInit()

  // LARGE PROFIT - TARGET
  if( TradeMode == TM_LONG )
  {
    if( Strategy_Trend==STRATEGY_LONGTREND_LEG_OF_THE_YEAR )
    {
      TargetPriceCommon = BasePriceLongTrend + 1.20 * SymbolBasedTargetPrice75Pct( Symbol() ) ;
    }
    else    // Strategy_Trend == STRATEGY_MEDIUMTREND_WEEKLY_LARGE_RANGE
    {
      TargetPriceCommon = TargetPriceMediumTrend;
    }
  }
  else
  {
    // -- TradeMode == TM_SHORT

    if( Strategy_Trend==STRATEGY_LONGTREND_LEG_OF_THE_YEAR )
    {
      TargetPriceCommon = BasePriceLongTrend - 1.20 * SymbolBasedTargetPrice75Pct( Symbol() ) ;
    }
    else    // Strategy_Trend == STRATEGY_MEDIUMTREND_WEEKLY_LARGE_RANGE
    {
      TargetPriceCommon = TargetPriceMediumTrend;
    }

  } // End of   if( TradeMode == TM_LONG ) for TAKING PROFIT




  /*++  PROFIT TARGET PRICE >> STRATEGY_MEDIUMTREND_WEEKLY_LARGE_RANGE  ++*/
  /*-----------------------------------------------------------------------------------*/  
  // OnInit()
  
  // MEDIUM PROFIT TARGET has its setting place directly on Trading Parameters setting 
  
  // extern  string      Header1a                  =
  //                                        "----------- Strategy Medium Exit Target Price ------------" ;
  // extern  double      TargetPriceMediumTrend    = 106.52 ;


  



  /*++  THRESHOLD PRICES  ++*/
  /*-----------------------------------------------------------------------------------*/
  // Threshold prices is for

  ThresholdProfitPips_Passed      = false ;

  ThresholdProfitPips_LowThresh   = 500.0   ;   // 800 pips
  ThresholdProfitPips_HighThresh  = SymbolBasedTargetPrice75Pct( Symbol() ) ;

  Print("") ;
  Print("") ;
  //Print(  "[OnInit]:" , " TakeProfit: ", IntegerToString( TakeProfit ) );
  Print(  "[OnInit]:" , " Symbol : ", Symbol() );
  Print(  "[OnInit]:" , " ThresholdProfitPips_LowThresh : ", DoubleToStr( ThresholdProfitPips_LowThresh ,4) );
  Print(  "[OnInit]:" , " ThresholdProfitPips_HighThresh: ", DoubleToStr( ThresholdProfitPips_HighThresh ,4) );
  Print("") ;
  Print("") ;




  /*++  RISK BOOSTER MESSAGE  ++*/
  /*-----------------------------------------------------------------------------------*/

  if ( RiskBooster == true )
  Print("[OnInit]:" ,
        " ****** RiskBoster is ON. P1, P2, P3 receives more sizing. ******"
      );
  Print("") ;
  Print("") ;



  /*++  RANDOM NUMBER GENERATOR   ++*/
  /*-----------------------------------------------------------------------------------*/

  //--- Initialize the generator of random numbers
  MathSrand(GetTickCount());




  /*++  LOCAL TIME MESSAGING  ++*/
  /*-----------------------------------------------------------------------------------*/

  //-- Time suffix comes with issue below
  string  timesuffix      =   TimeToString( TimeLocal() , TIME_DATE  ) + " "
                          +   IntegerToString( TimeHour(TimeLocal()) ) + "."
                          +   IntegerToString( TimeMinute( TimeLocal() ))   + "."
                          +   IntegerToString( TimeSeconds( TimeLocal() ))
  ;


  //-- ***************************
  //-- ******** DEBUGGING ********
  //-- ***************************

  Print("");
  Print( "[OnInit]: Time Suffix : " , timesuffix );
  Print( "[OnInit]: TimeCurrent : " , TimeToStr( TimeCurrent(), TIME_DATE ) );
  Print( "[OnInit]: TimeLocal   : " , TimeToStr( TimeLocal()  , TIME_DATE ) );
  Print( "[OnInit]: TimeGMT     : " , TimeToStr( TimeGMT()    , TIME_DATE ) );
  Print("");

  /*--------------------------------------------------------------------------------*\
  ISSUE FOUND
  Issues with TimeCurrent() , TimeLocal() , and TimeGMT() on Strategy Tester
  All three functions returned THE SAME VALUE!!
  \*--------------------------------------------------------------------------------*/




  /*++  REPORTING FILES IN CSV  ++*/
  /*-----------------------------------------------------------------------------------*/


  //FileStringEquity_PeakAndDrawdown = Symbol() + "_EqPeakDD_" + timesuffix + ".CSV" ;
  FileStringEquity_PeakAndDrawdown = Symbol() + "_EqPeakDD_" + MathRand() + ".CSV" ;
  //-- the timesuffix does not work for Tester; all time functions (TimeCurrent , TimeLocal,
  //-- TimeGMT returns the same value, the time of the first tick on simulation ! )


  ResetLastError();

  /*
  Folder:
  C:\Users\Hendy\AppData\Roaming\MetaQuotes\Terminal\50CA3DFB510CC5A8F28B48D1BF2A5702\tester\files
  */

  FileHandle_OHLC_Equity = FileOpen( FileStringEquity_PeakAndDrawdown , FILE_WRITE|FILE_CSV );

  if(FileHandle_OHLC_Equity == INVALID_HANDLE)
   {
      Print("");
      Print("[OnInit]: Operation FileOpen ", FileStringEquity_PeakAndDrawdown ," failed, error ",GetLastError());
      Print("");
   }
  else
    {
      FileWrite( FileHandle_OHLC_Equity
              ,   "DateTime"
              ,   "Symbol"
              ,   "Timeframe"
              ,   "Open"
              ,   "High"
              ,   "Low"
              ,   "Close"
              ,   "Volume"
              ,   "AccountBalance"
              ,   "AccountEquity"
              ,   "Total Lots"

              ,   "Peak Equity"
              ,   "Drawdown Equity"
              ,   "Drawdown %"
              ,   "Max Drawdown Equity"
              ,   "Max Drawdown %"
              ,   "Recovery Ratio"

              ,   "Ratio"
              ,   "DateRangeInQuarter"
              ,   "Cycles"
              ,   "PDD"
              ,   "ICQGR"
              ,   "FREQUENCY"
              ,   "QCQGR"
              ,   "MAR"


          );
      Print("");
      Print("[OnInit]: File Open ", FileStringEquity_PeakAndDrawdown , " is successful");
      Print("");
    }



  //-- Alert Initialization
  Alert("[OnInit]: Expert Adviser ", SystemName ," ",VersionSeries ," ", VersionDate ," has been launched");

  //-- Marks the end of Initialization
  Print("OnInit INITIALIZATION is SUCCESSFUL");

  return(INIT_SUCCEEDED);
  }



  
  
  
  
  
//+-------------------------------------------------------------------------------------------------+
//| Expert deinitialization function                                                                |
//+-------------------------------------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
      FileClose(FileHandle_OHLC_Equity);

  }









/***************************************************************************************************/
/***   REPORTING FUNCTION   ***/
/***************************************************************************************************/

//-- Use [MVTS_4_HFLF_Model_A.mq4] as master file


void Track_EquityPeakAndDrawdown(
    double   &InitialEquity     ,
    double   &PeakEquity        ,
    double   &DrawdownEquity    ,
    double   &DrawdownPercent   ,
    double   &DrawdownMaxEquity ,
    double   &DrawdownMaxPercent,
    double   &RecoveryRatio
    )
{

  //-- Tracking equity-drawdown variables

  if( AccountEquity() > PeakEquity )
      PeakEquity = AccountEquity() ;

  if( AccountEquity() < PeakEquity  )
      DrawdownEquity = ( PeakEquity - AccountEquity() );

  if( DrawdownMaxEquity < DrawdownEquity )
      DrawdownMaxEquity = DrawdownEquity ;

  if( PeakEquity > 0 )
    {
      DrawdownPercent = DrawdownEquity / PeakEquity ;
      if( DrawdownMaxPercent < DrawdownPercent  )
          DrawdownMaxPercent = DrawdownPercent  ;
    }
  else
    {
      Print(  "[Track_EquityPeakAndDrawdown]: " ,
              " WARNING: PeakEquity < 0. PeakEquity is $"  , DoubleToStr( PeakEquity ,2 )
          ,   " / Account Equity is $"                  , DoubleToStr( AccountEquity() , 2 )
          );
    }

  if( DrawdownMaxEquity != 0 )
      RecoveryRatio = (AccountEquity() - InitialEquity ) / DrawdownMaxEquity ;
  else
      RecoveryRatio = 0.0 ;


} // End of void Track_EquityPeakAndDrawdown ()


void REPORT_Equity_PeakAndDrawdown (
        bool    &IsFirstTick_HTF ,
        double  &PeakEquity          ,
        double  &DrawdownEquity      ,
        double  &DrawdownPercent     ,
        double  &DrawdownMaxEquity   ,
        double  &DrawdownMaxPercent  ,
        double  &RecoveryRatio
    )
  {

    //-- Report on OHLC, Equity, and Balance

    if( IsFirstTick_HTF==true
        //  && OutputReport == YES
        )
      {

        static datetime _first_datetime = iTime( Symbol() , Period() , 0 ) ;
        static double   _initial_equity = AccountEquity() ;

        double      _total_lots ;
        int         _total_orders ;

        datetime    _current_datetime ;
        double      _daterange_quarter ;
        double      _cycles ;
        double      _ratio ;
        double      _PDD ;
        double      _ICQGR ;
        double      _QCQGR ;
        double      _FREQUENCY ;
        double      _MAR ;


        //-- Total Lots

        _total_orders = OrdersTotal();
        _total_lots   = 0.0;

        for(int i=0 ; i < _total_orders ; i++ )
        {
          if( OrderSelect(i , SELECT_BY_POS , MODE_TRADES ) )
          {
            if( (OrderType() == OP_BUY || OrderType() == OP_SELL) && OrderCloseTime() == 0 )
                  _total_lots += OrderLots() ;
               // End of if( (OrderType() == OP_BUY || OrderType() == OP_SELL ) ...
          } // End of if( OrderSelect(i , SELECT_BY_POS , MODE_TRADES ) )
        }   // End of for(int i=0 ; i < _total_orders ; i++ )



        //-- Calculate ICQGR / QCQGR / Frequency / MAR

        _current_datetime   = iTime( Symbol() , Period() , 0 ) ;
        _daterange_quarter  = ( _current_datetime - _first_datetime  ) / ( PeriodSeconds(PERIOD_D1) * 365.25 / 4 ) ;

            if (_daterange_quarter != 0)
              {
                _cycles = 1 / _daterange_quarter ;
              }
            else
              {
                _cycles = 0.0 ;
              }

        _ratio              = AccountEquity() / _initial_equity ;
        _PDD                = DrawdownMaxPercent ;
        if(_daterange_quarter != 0)
          {
            _ICQGR              = MathLog( _ratio ) / _daterange_quarter ;
          }
        else
          {
            _ICQGR = 0.0 ;
          }

        _QCQGR              = MathPow( _ratio , _cycles ) - 1 ;

        if( _PDD != 0 )
          {
            _FREQUENCY      = _ICQGR / _PDD ;
            _MAR            = _QCQGR / _PDD ;
          }
        else
          {
            _FREQUENCY  = 0.0 ;
            _MAR        = 0.0 ;
          }




        //-- Optimization variables
        // optimizeMAR         = _MAR ;
        // optimizeFrequency   = _FREQUENCY ;
        // optimizeRecoveryRatio = RecoveryRatio ;




        if(FileHandle_OHLC_Equity != INVALID_HANDLE)
          {
          FileWrite(FileHandle_OHLC_Equity
                ,   iTime( Symbol() , Period() , 0 )                // Time as of IsFirstTick_HTF == true
                ,   Symbol()
                ,   EnumToString( PERIOD_D1 )                       // PERIOD_D1 due to reporting on D1 bar
                ,   iOpen(Symbol() , Period() , 1 )
                ,   iHigh(Symbol() , Period() , 1 )
                ,   iLow(Symbol() , Period() , 1 )
                ,   iClose(Symbol() , Period() , 1 )
                ,   iVolume(Symbol() , Period() , 1 )
                ,   DoubleToString( AccountBalance() , 2)           // Balance as of IsFirstTick_HTF == true
                ,   DoubleToStr( AccountEquity() , 2)               // Equity as of IsFirstTick_HTF == true
                ,   DoubleToStr( _total_lots , 2 )

                ,   PeakEquity
                ,   DrawdownEquity
                ,   DrawdownPercent
                ,   DrawdownMaxEquity
                ,   DrawdownMaxPercent
                ,   DoubleToStr( RecoveryRatio , 2 )

                ,   DoubleToStr( _ratio             , 6   )
                ,   DoubleToStr( _daterange_quarter , 6   )
                ,   DoubleToStr( _cycles            , 6   )
                ,   DoubleToStr( _PDD               , 6   )
                ,   DoubleToStr( _ICQGR             , 6   )
                ,   DoubleToStr( _FREQUENCY         , 2   )
                ,   DoubleToStr( _QCQGR             , 6   )
                ,   DoubleToStr( _MAR               , 2   )

                );
          } // // End of if(FileHandle_OHLC_Equity != INVALID_HANDLE)
      } // if( IsFirstTick_HTF==true && OutputReport == YES )
  }     // End of void REPORT_Equity_PeakAndDrawdown()









/***************************************************************************************************/
/***   EXIT BLOCK   ***/
/***************************************************************************************************/




/*-------------------------------------------------------------------------------------------------*/
/****** EXIT BY EXCLUSION PERIOD RULE ******/
/*-------------------------------------------------------------------------------------------------*/

//-- Exclusion Period Rule is to exit **MARKET** due to extra ordinary event, such as BREXIT


void EXIT_EXCLZONE(
        bool    &closedByTechnicalAnalysis ,
        // double  &RInitPips ,
        // double  &RMult_Final ,
        string  &comment_exit
        )

// All parameters are borrowed from EXIT_LONG

{

    if( ExclZone_In  )
    //-- ExclZone_In is a GLOBAL variable; hence no parameters

    {

          // --------------------------------------------------------------
          // Exit from *ALL* open position ; BUYING or SELLING
          // --------------------------------------------------------------

          int   TotalOrders = OrdersTotal();

          for (int i=TotalOrders-1 ; i>=0 ; i--)

          //-- "Back loop" because after order close,
          //--  this closed order removed from list of opened orders.
          //-- https://www.mql5.com/en/forum/44043

          {
            //-- Select the order
            closedByTechnicalAnalysis = OrderSelect( i , SELECT_BY_POS , MODE_TRADES );

            if (!closedByTechnicalAnalysis)
              {
                string _errMsg ;
                  _errMsg = "Failed to select order to close. Error: " + GetLastError() ;
                Print( _errMsg );
                Alert( _errMsg );
                Sleep(3000);
              }

              int type   = OrderType();

              bool result = false;

              switch(type)
              {
                //Close opened long positions
                case OP_BUY       : result = OrderClose( OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), 5, Red );
                                    break;

                //Close opened short positions
                case OP_SELL      : result = OrderClose( OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), 5, Red );
                                    break;

                //Close pending orders
                case OP_BUYLIMIT  :
                case OP_BUYSTOP   :
                case OP_SELLLIMIT :
                case OP_SELLSTOP  : result = OrderDelete( OrderTicket() );
              }

              if(result == false)
              {
                Alert("Order " , OrderTicket() , " failed to close. Error:" , GetLastError() );
                Sleep(3000);
              }
              else
              {
                //Print("");
                Print("[EXIT_EXCLZONE]: " ,
                      " Closing Iteration: " , (i+1) , " out of " , TotalOrders ,
                      " Closed order of ticket #" , OrderTicket() ,
                      " OrderLots: " , DoubleToStr( OrderLots() , 2) ,
                      " Note, closing price exists in the next tick."
                    );
                //Print("");

              } // End of ELSE on "if(result == false)"
          } // End of "for (int i=TotalOrders-1 ; i>=0 ; i--)"


    }

}       // End of void EXIT_EXCLZONE()






/*-------------------------------------------------------------------------------------------------*/
/****** EXIT ALL BY TECHNICAL RULE ******/
/*-------------------------------------------------------------------------------------------------*/

void  EXIT_ALL_POSITIONS(
        bool    &closedByTechnicalAnalysis ,
        // double  &RInitPips ,
        // double  &RMult_Max ,
        // double  &RMult_Final ,
        string  &comment_exit
                        )
{

          // --------------------------------------------------------------
          // Exit from *ALL* open trade position ; BUYING or SELLING
          // --------------------------------------------------------------

          int   TotalOrders = OrdersTotal();
          int   TotalOrdersClosed = 0;

          for (int i=TotalOrders-1 ; i>=0 ; i--)

          //-- "Back loop" because after order close,
          //--  this closed order removed from list of opened orders.
          //-- https://www.mql5.com/en/forum/44043

          {
            //-- Select the order
            closedByTechnicalAnalysis = OrderSelect( i , SELECT_BY_POS , MODE_TRADES );

            if (!closedByTechnicalAnalysis)
              {
                string _errMsg ;
                  _errMsg = "Failed to select order to close. Error: " + GetLastError() ;
                Print( _errMsg );
                Alert( _errMsg );
                Sleep(3000);
              }

              int type   = OrderType();

              bool result = false;

              switch(type)
              {
                //Close opened long positions
                case OP_BUY       : result = OrderClose( OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), 5, Red );
                                    TotalOrdersClosed++ ;
                                    Print("[EXIT_ALL_POSITIONS]: ",
                                          "Close Ticket: #" , IntegerToString(OrderTicket()) , " is closed." ,
                                          " OpenPrice(): " ,      DoubleToString( OrderOpenPrice() ,2 )   ,
                                          " ClosedPrice(): " ,    DoubleToString( OrderClosePrice() ,2 )  ,
                                          " OrderLots: " , DoubleToStr( OrderLots() , 2) ,
                                          " OrderProfit PIPS: " ,
                                              DoubleToString( ( OrderClosePrice()-OrderOpenPrice() ) / (Point * PointToPrice)
                                                ,0 )  ,
                                          " OrderCloseTime():",   OrderCloseTime() ,
                                          " OrderProfit(): " ,    DoubleToString(OrderProfit() , 2)  ,
                                          " Total Position closed: " , IntegerToString(TotalOrdersClosed) );
                                    break;

                //Close opened short positions
                case OP_SELL      : result = OrderClose( OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), 5, Red );
                                    TotalOrdersClosed++ ;
                                    Print("[EXIT_ALL_POSITIONS]: ",
                                          "Close Ticket: #" , IntegerToString(OrderTicket()) , " is closed." ,
                                          " OpenPrice(): " ,      DoubleToString( OrderOpenPrice() ,2 )   ,
                                          " ClosedPrice(): " ,    DoubleToString( OrderClosePrice() ,2 )  ,
                                          " OrderLots: " , DoubleToStr( OrderLots() , 2) ,
                                          " OrderProfit PIPS: " ,
                                              DoubleToString( ( OrderOpenPrice() - OrderClosePrice() ) / (Point * PointToPrice)
                                                ,0 )  ,
                                          " OrderCloseTime():",   OrderCloseTime() ,
                                          " OrderProfit(): " ,    DoubleToString(OrderProfit() , 2)  ,
                                          " Total Position closed: " , IntegerToString(TotalOrdersClosed) );
                                    break;

                //Close pending orders
                case OP_BUYLIMIT  :
                case OP_BUYSTOP   :
                case OP_SELLLIMIT :
                case OP_SELLSTOP  : result = OrderDelete( OrderTicket() );
              }

              if(result == false)
              {
                Alert("Order " , OrderTicket() , " failed to close. Error:" , GetLastError() );
                Sleep(3000);
              }
              else
              {
                //Print("");
                Print("[EXIT_ALL_POSITIONS]: " ,
                      " Closing Iteration: " , (i+1) , " out of " , TotalOrders
                    );
                //Print("");

              } // End of ELSE on "if(result == false)"

          }   // End of "for (int i=TotalOrders-1 ; i>=0 ; i--)"

          comment_exit =
              "[EXIT_ALL_POSITIONS]: " +
              "All " + IntegerToString(TotalOrdersClosed) + " are exited.";

          Print( comment_exit );

} // End of void EXIT_ALL_POSITIONS






/*-------------------------------------------------------------------------------------------------*/
/****** EXIT SHORT BY TECHNICAL RULE ******/
/*-------------------------------------------------------------------------------------------------*/







/*-------------------------------------------------------------------------------------------------*/
/****** EXIT JOURNALING - BY TECHNICAL RULE ******/
/*-------------------------------------------------------------------------------------------------*/


/*-------------------------------------------------------------------------------------------------*/
/****** EXIT JOURNALING - BY STOP / TARGET ******/
/*-------------------------------------------------------------------------------------------------*/










/***************************************************************************************************/
/***   ENTRY BLOCK   ***/
/***************************************************************************************************/


void Execute_Entry_Buy_PMultiple( int &max_position , double  &atr_1 , string &comment_for_ticket)
{

    int ticket ;

    // TradeFlag_ClosedOnBigProfit must be FALSE to continue
    if( TradeFlag_ClosedOnBigProfit == true )
    {
      Print("[Execute_Entry_Buy_PMultiple]:" ,
        " TradeFlag_ClosedOnBigProfit is TRUE.",
        " No New Trade entered." ,
        " Execute_Entry_Buy_PMultiple() is cancelled"
        );
      return;
    }


    //-- Check positions:
    //-- Position P1 must NOT exist to enter P1

    //-- To enter Position P2,
    //-- Position P2 must NOT exist, Position P1 MUST EXIST
    //-- and Position P1 must IN PROFIT

    //-- To enter Position P3,
    //-- Position P3 must NOT exist, Position P1, P2 MUST EXIST
    //-- and Position P1, P2, must IN PROFIT

    //-- To enter Position P4,
    //-- Position P4 must NOT exist, Position P1, P2, P3 MUST EXIST
    //-- and Position P1, P2, P3, must IN PROFIT

    int iPos ; //-- variable iPos applicable to the rest of statements in this procedure

    for( iPos = 1 ; iPos <= max_position ; iPos++)
    {

      int magic_number = MagicNumberTable( Symbol() , iPos );
      //-- Check first position --> P1

      if( iPos == 1 )
      {

          if( FindThenSelectOpenOrder( magic_number , ticket )  )
          //-- the FindThenSelectOpenOrder returns ticket by reference
          {
            Print(  "[Execute_Entry_Buy_PMultiple] @ iPos-" , IntegerToString( iPos ) ,
              " Position P1 exists.",
              " Ticket #" , IntegerToString(ticket) ,
              " Execute_Entry_Buy_PMultiple considers next position/s." ) ;

            // Position 1 exists, not closed, go to the next loop to consider next position
            // iPos will be raised to 2 in the next loop
            continue;
          }

          break;    //-- exit this loop, execute the buying

      } //-- if( iPos == 1 )
      else    //-- iPos > 1
      {

         // Print(  "[Execute_Entry_Buy_PMultiple] @ iPos: " , IntegerToString( iPos ) ,
              // " **** DEBUGGING ****") ;

         // FINDING - DEBUGGING
         // The issue is iPos is raised to check subsequent pyramiding
         // the raised iPos value goes to the max_position
         // Delete this later
         // Solution: pick the iPos for opened position as lastPos
         // then, use lastPos+1 for the next pyramid position




          // Current position MUST NOT EXIST
          // ALL Previous positions MUST EXIST
          // ALL Previous positions MUST in PROFIT

          magic_number = MagicNumberTable( Symbol() , iPos );

          if( FindThenSelectOpenOrder( magic_number , ticket ) == false  )
          {
            Print(  "[Execute_Entry_Buy_PMultiple] @ iPos-" , IntegerToString( iPos ) ,
              " Position P" , IntegerToString(iPos) , " NOT EXIST.",
              " Ticket #" , IntegerToString(ticket) ,
              " Execute_Entry_Buy_PMultiple considers next position/s."  ,
              " BREAK from the loop at iPos=" , iPos
              ) ;

            // Position iPos not exists, not closed, go to the next loop to consider next position
            // iPos count stops here
            break;
          }
          else
          {
            Print("[Execute_Entry_Buy_PMultiple] @ iPos-" , IntegerToString( iPos ) ,
              " Position P" , IntegerToString(iPos) , " EXISTs.",
              " Ticket #" , IntegerToString(ticket) ,
              " Execute_Entry_Buy_PMultiple continue the loop." ) ;
          }

      } //-- End of else if( iPos > 1 )

    } //-- End of for(int iPos = 1 ; iPos <= max_position ; iPos++)





    //-- Check all previous position MUST EXIST
    //-- Done by previous loop (IMPLICITLY)

    //-- Check all previous position MUST IN PROFIT
    //-- Start from the most recent previous position
    for( int j=iPos-1 ; j >= 1 ; j-- )
    {
      int magic_number = MagicNumberTable( Symbol() , j );
      if( FindThenSelectOpenOrder( magic_number , ticket ) )
      {
        if ( OrderProfit() <= 0.01 )
        {
          // Print("[Execute_Entry_Buy_PMultiple] @ Pos: " , IntegerToString( j ) ,
                // " Position P" , IntegerToString(j) , " with ticket #",ticket," is NOT PROFITABLE",
                // " so that, CANCEL adding position for P" , iPos
                // ) ;

          Print("[Execute_Entry_Buy_PMultiple]: " ,
                " Cancel adding new position P" , iPos ,
                ", because previous position P",  j ," is NOT PROFITABLE."
                " Position P",j,"'s ticket is #" , ticket
                );

          // previous position MUST be profitable, otherwise exit procedure
          return ;
        }
      } // End of if( FindThenSelectOpenOrder( magic_number , ticket ) )

    } // End of for( int j=iPos-1 ; j >= 1 ; j-- )




    //+-----------------------------------------------------------------+
    //| iPos# < max_position                                            |
    //+-----------------------------------------------------------------+

    int magic_number = MagicNumberTable( Symbol() , max_position );
    if( FindThenSelectOpenOrder( magic_number , ticket ) )
    {
      Print("[Execute_Entry_Buy_PMultiple] @ Pos: " , IntegerToString( max_position ) ,
            " MAX Position P" , IntegerToString(max_position) , " exist.",
            " Ticket #" , IntegerToString(ticket) ,
            " so that, NO MORE adding position."
            ) ;
      return;
    }






    //+-----------------------------------------------------------------+
    //| DailyCountEntry MUST be < DailyEntryMax                         |
    //+-----------------------------------------------------------------+

    if ( DailyCountEntry >=  DailyEntryMax)
    {
      Print("[Execute_Entry_Buy_PMultiple] @ iPos: " , IntegerToString( iPos ) ,
            " DailyCountEntry is " , IntegerToString(DailyCountEntry) ,
            " Entry is cancelled due to daily limit of ",DailyEntryMax," has been filled."
            );
      return;
    }




    //*******************************************************************
    //| Execute BUY iPos                                                |
    //*******************************************************************
    //- Core action for buying


    double  plannedStop     = Bid - NATR * atr_1 ;

    if( (NATR * atr_1) > CapOnStopDistancePips * Point * PointToPrice )    // Cap stop distance
      {
        plannedStop = Bid - CapOnStopDistancePips * Point * PointToPrice ;
        Print("[Execute_Entry_Buy_PMultiple]:" ,
              " ----> CAP Distance " , DoubleToString( CapOnStopDistancePips , 0) , " pips is reached" ,
              " planned stop = " , DoubleToString(plannedStop , 4)
             );
      }

    double  priceAsk        = Ask;
    
    ENUM_TRADEDIRECTION     direction = DIR_BUY ;



    //------------------------------------------------------------------
    //-- Risk per trade markups
    //-- Pos 1: + 0.5% , Pos 2: +0.5%, Pos 3: +0.5%, 4 beyond: no markup
    //------------------------------------------------------------------

    double risk_markup = 0.0;

    if( RiskBooster == true )
    //-- Give a booster to the risk per trade for more position sizing
    {

        switch( iPos )
        {
          case 1: risk_markup = 1.0 / 100.0 ; break;    //-- mark up by adding +1.0%
          case 2: risk_markup = 0.5 / 100.0 ; break;    //-- mark up by adding +0.5%
          case 3: risk_markup = 0.5 / 100.0 ; break;    //-- mark up by adding +0.5%
          default: risk_markup = 0.0        ; break;
        } //-- switch( iPos )

    } //-- if( RiskBooster == true )


    double risk_per_trade = ( RiskPerTrade + risk_markup ) ;

    //-- Complete risk per trade calculation


    double lots_position = LotSize( priceAsk , plannedStop , direction , risk_per_trade );

    if( !HiddenStopLossTarget )
    {

      ticket = OrderSend(
                      Symbol()
                  ,   OP_BUY
                  ,   lots_position
                  ,   priceAsk
                  ,   3
                  ,   plannedStop
                  ,   TargetPriceCommon       // TargetPriceCommon is calculated on OnInit()
                  ,   "Entry Buy Signal #: " + IntegerToString( EntrySignalCountBuy )
                      + " Cmnt: " + comment_for_ticket
                  ,   MagicNumberTable( Symbol() , iPos )
                  ,   0
                  ,   clrGreen
                  );

    }   // End of if( !HiddenStopLossTarget )
    else
    {

      //-- Resize the PositionTracker to fit just the position; not excessive
      //-- So that, we can use ArrayRange() to focus on the position number
      // ArrayResize( PositionTracker , iPos ) ;

      //- Resetting the record
      PositionTracker[iPos].Ticket      = 0       ;
      PositionTracker[iPos].PositionSequence = 0  ;
      PositionTracker[iPos].openPrice   = 0.0     ;   //-- This is not actual entry price
      PositionTracker[iPos].SL          = 0.0     ;
      PositionTracker[iPos].TP          = 0.0     ;
      PositionTracker[iPos].openTime    = 0       ;
      PositionTracker[iPos].magicNumber = 0       ;
      PositionTracker[iPos].MarkedToClose = false ;

      //-- Open the order
      ticket = OrderSend(
                      Symbol()
                  ,   OP_BUY
                  ,   lots_position
                  ,   priceAsk
                  ,   3
                  ,   0           //--  plannedStop is set to 0
                  ,   0           //-- TargetPriceCommon
                  ,   "Entry Buy Signal #: " + IntegerToString( EntrySignalCountBuy )
                      + " Cmnt: " + comment_for_ticket
                  ,   MagicNumberTable( Symbol() , iPos )
                  ,   0
                  ,   clrGreen
                  );

      //-- Record tracker for the position
      PositionTracker[iPos].Ticket        = ticket            ;
      PositionTracker[iPos].PositionSequence = iPos           ;
      PositionTracker[iPos].openPrice     = priceAsk          ;   //-- This is not actual entry price
      PositionTracker[iPos].SL            = plannedStop       ;
      PositionTracker[iPos].TP            = TargetPriceCommon ;
      PositionTracker[iPos].openTime      = Time[0]           ;
      PositionTracker[iPos].magicNumber   = MagicNumberTable( Symbol() , iPos ) ;
      PositionTracker[iPos].MarkedToClose = false ;
      //-- NOTE for peace of mind, see again Lucas Liew course
      //-- for part of hidden stop and hidden target


    } // End of ELSE on if( !HiddenStopLossTarget )


      //*****************//
      //*** DEBUGGING ***//
      //*****************//
      Print("");
      Print("***********************************");
      Print(
              "[Execute_Entry_Buy_PMultiple]:"
            , " iPos : "          , IntegerToString(iPos)
            , " Ticket: #"        , IntegerToString(ticket)
            , " Ask: "            , DoubleToString(priceAsk ,2)   //-- Actual entry price available in the next tick !!
            , " NATR: "           , DoubleToString(NATR ,1)
            , " atr_1: "          , DoubleToString(atr_1 ,5)
            , " atr_1 pips: "     , DoubleToString((atr_1 / (Point * PointToPrice) ) ,0)
            , " Distance NATR: "  , DoubleToString( NATR * atr_1 , 5)
            , " Distance NATR pips: "   , DoubleToString( (NATR * atr_1)/(Point * PointToPrice) ,0)
            , " Distance Actual pips: " , DoubleToString( (priceAsk - plannedStop) / (Point * PointToPrice) ,0  )
            , " Plan Tgt Price: " , DoubleToString( TargetPriceCommon , 2 )
            , " Plan Target Pips: ",  DoubleToString( (TargetPriceCommon - priceAsk)/(Point * PointToPrice) , 0)
            , " Lot: "            , DoubleToString( lots_position , 2)
            , " Risk Per Trade: " , DoubleToString( (risk_per_trade * 100.0) , 2 ) , "%"
          );
      Print("***********************************");
      Print("");

      //-- NOTE: Actual entry price only available in the next tick !


    if(ticket < 0)
      {

        //-- Entering BUY FAILED

        int _errNumber = GetLastError();
        Alert("[Execute_Entry_Buy_PMultiple]: " ,
              " iPos#: "          , IntegerToString(iPos) ,
              " Error Sending Order BUY!" ,
              " Error Number: "      , IntegerToString( _errNumber ) ,
              " Error Description: " , GetErrorDescription( _errNumber )
              );

      }
    else
    {

        //-- Entering BUY SUCCESSFUL

        // increase daily count entry after entry
        DailyCountEntry++ ;

            //-- DEBUGGING
            if( DailyCountEntry >= DailyEntryMax )
            {
              Print("[Execute_Entry_Buy_PMultiple]:" ,
                    " iPos#: "          , IntegerToString(iPos) ,
                    " REACHED MAX DAILY ENTRY."   ,
                    " DailyCountEntry: " , IntegerToString(DailyCountEntry)
                   );
            }


        // mark the order is opened
        // flag_OrderOpen[iPos] = true ;

        // mark closed by technical analysis is false
        // closedByTechnicalAnalysis = false ;

        // RESET Trade profit threshold flag
        TradeFlag_ProfitThresholdPassed = false ;


        //--------------
        //-- DEBUGGING
        //--------------

        Print("[Execute_Entry_Buy_PMultiple]:" ,
              " DEBUGGING - iPos#: "          , IntegerToString(iPos)
            );

        // RESET Breakeven_iPos_Applied
        Breakeven_iPos_Applied[iPos] = false ;

        // RESET ProfitLock250Pips_iPos_Applied
        ProfitLock250Pips_iPos_Applied[iPos] = false ;

        int _errNumber = GetLastError();
        if( _errNumber > 0 )
        {
          Print("[Execute_Entry_Buy_PMultiple]:" ,
              " iPos#: "          , IntegerToString(iPos) ,
              " Error #" , IntegerToString(_errNumber) ,
                ": " , GetErrorDescription(_errNumber)
            );
        } // End of if( _errNumber > 0 )






        //------------------------------------------------------------------
        //-- Calculate entry price distance in pips between P1, P2, P3, ...
        //------------------------------------------------------------------

        if( iPos > 1)
        {
          int     mn_curr   ;   // Magic Numbers
          int     mn_prev   ;
          int     mn_first  ;

          int     tk_curr   ;   // Tickets
          int     tk_prev   ;
          int     tk_first  ;

          double  opnprice_curr   ;
          double  opnprice_prev   ;
          double  opnprice_first   ;


          //-- Find the open price for the first position
          mn_first = MagicNumberTable( Symbol() , 1 );
          if( FindThenSelectOpenOrder( mn_first , tk_first ) )
            opnprice_first = OrderOpenPrice() ;
          else
            Print("[Execute_Entry_Buy_PMultiple]:" ,
                  " *** WARNING *** P1 is NOT FOUND!! Order missing !!!"
                  );


          if( iPos == 2 )
          {

            mn_curr = MagicNumberTable( Symbol() , iPos )  ;
            if( FindThenSelectOpenOrder( mn_curr , tk_curr ) )
              opnprice_curr = OrderOpenPrice() ;
            else
                  Print("[Execute_Entry_Buy_PMultiple]:" ,
                        " *** WARNING *** P2 is NOT FOUND!! Order missing !!!"
                        );

            Print("[Execute_Entry_Buy_PMultiple]:" ,
                  " Dist in pips P1 to P2: " ,
                      DoubleToString( (opnprice_curr - opnprice_first)/(Point * PointToPrice), 0 )
                  );

          }   // End of if( iPos == 2 )
          else
          {

            for( int j=2 ; j<=iPos ; j++ )
            {

              mn_prev = MagicNumberTable( Symbol() , j-1 );
              if( FindThenSelectOpenOrder( mn_prev , tk_prev ) )
                opnprice_prev = OrderOpenPrice();
                else  Print("[Execute_Entry_Buy_PMultiple]: WARNING ORDER P", (j-1) , " NOT FOUND");

              mn_curr = MagicNumberTable( Symbol() , j );
              if( FindThenSelectOpenOrder( mn_curr , tk_curr) )
                opnprice_curr = OrderOpenPrice();
                else  Print("[Execute_Entry_Buy_PMultiple]: WARNING ORDER P", (j) , " NOT FOUND");

              Print("[Execute_Entry_Buy_PMultiple]:" ,
                    " Dist in pips P", (j-1) ," to P",j,": " ,
                        DoubleToString( (opnprice_curr - opnprice_prev)/(Point * PointToPrice), 0 )
                    );

              if( j==iPos )   //-- Final distance - P1 to the existing P
              Print("[Execute_Entry_Buy_PMultiple]:" ,
                    " Dist in pips P1 to P",j,": " ,
                        DoubleToString( (opnprice_curr - opnprice_first)/(Point * PointToPrice), 0 )
                    );

            } // End of for( int j=3 ; j<=iPos ; j++ )

          } // End of ELSE on if( iPos == 2 )


        } //-- End of if( iPos > 1)










        //*****************//
        //*** DEBUGGING ***//
        //*****************//

          //-- Add text under arrow
          string  entryDetails1 ;
          string  entryDetails2 ;
          string  entryDetails3 ;
          entryDetails1 =
                            "P"+ IntegerToString(iPos) + " Ticket #" + IntegerToString(ticket)
                + "/ \n" +  "Time: "      + TimeToStr(Time[0] , TIME_MINUTES )
                + "/ \n" +  "Ask: "       + DoubleToString(priceAsk , 2)
                + "/ \n" +  "NATR: "      + DoubleToString(NATR , 1)
                ;
          entryDetails2 =
                            "ATR: "       + DoubleToString(atr_1 , 4)
                + "/ \n" +  "Stop: "      + DoubleToString(plannedStop , 2)
                + "/ \n" +  "Dist Pips: " + DoubleToString((NATR * atr_1)/(Point * PointToPrice) , 2)
                + "/ \n" +  "LotSize: "   + DoubleToString(lots_position , 4)
                ;
          entryDetails3 =
                            "Target: "    + DoubleToString(TargetPriceCommon , 2)
                + "/ \n" +  "Magic Number: " + IntegerToString( MagicNumberTable( Symbol() , iPos ))
                      ;
          string  txtName = "entdtl1 " + TimeToStr(Time[0] , TIME_DATE|TIME_MINUTES ) ;
          ObjectCreate( txtName , OBJ_TEXT , 0 , Time[0] , Low[1] - 12.0 * Point );
          ObjectSetText( txtName , entryDetails1 ,9 , "Arial" , clrGreen );

                  txtName = "entdtl2 " + TimeToStr(Time[0] , TIME_DATE|TIME_MINUTES ) ;
          ObjectCreate( txtName , OBJ_TEXT , 0 , Time[0] , Low[1] - 16.0 * Point );
          ObjectSetText( txtName , entryDetails2 ,9 , "Arial" , clrGreen );

                  txtName = "entdtl3 " + TimeToStr(Time[0] , TIME_DATE|TIME_MINUTES ) ;
          ObjectCreate( txtName , OBJ_TEXT , 0 , Time[0] , Low[1] - 20.0 * Point );
          ObjectSetText( txtName , entryDetails3 ,9 , "Arial" , clrGreen );

        //*********************//
        //*** END Debugging ***//
        //*********************//


          // Initialize trading journal
          // MAEPips     = 0.0 ;
          // MFEPips     = 0.0 ;
          // RMult_Max   = 0.0 ;
          // RMult_Final = 0.0 ;

          // #TRICKY FOUND
          // RInitPips   = (OrderOpenPrice() - OrderStopLoss()) / Point() ;
          // OrderOpenPrice() / OrderStopLoss() : 0.0 / 0.0
          // OrderOpenPrice() and OrderStopLoss() ARE AVAILABLE IN THE NEXT TICK !!!



          // Validate how much the slippage
          //if( OrderSelect(ticket for P1 , SELECT_BY_TICKET , MODE_TRADES ) == true )
          //  {
          //    double actualOpenPrice = OrderOpenPrice();
          //    Print( "SLIPPAGE TEST: Price Ask vs ActualEntry Price and difference: "
          //            , priceAsk , " / " , actualOpenPrice , " / " , (actualOpenPrice - priceAsk) );
          //  }


    } //-- Entry buy SUCCESSFUL





} //-- End of void Execute_Entry_Buy_PMultiple()







void Execute_Entry_Sell_PMultiple( int &max_position , double  &atr_1 , string &comment_for_ticket)
{

    int ticket ;

    // TradeFlag_ClosedOnBigProfit must be FALSE to continue
    if( TradeFlag_ClosedOnBigProfit == true )
    {
      Print("[Execute_Entry_Sell_PMultiple]:" ,
        " TradeFlag_ClosedOnBigProfit is TRUE.",
        " No New Trade entered." ,
        " Execute_Entry_Sell_PMultiple() is cancelled"
        );
      return;
    }


    //-- Check positions:
    //-- Position P1 must NOT exist to enter P1

    //-- To enter Position P2,
    //-- Position P2 must NOT exist, Position P1 MUST EXIST
    //-- and Position P1 must IN PROFIT

    //-- To enter Position P3,
    //-- Position P3 must NOT exist, Position P1, P2 MUST EXIST
    //-- and Position P1, P2, must IN PROFIT

    //-- To enter Position P4,
    //-- Position P4 must NOT exist, Position P1, P2, P3 MUST EXIST
    //-- and Position P1, P2, P3, must IN PROFIT

    int iPos ; //-- variable iPos applicable to the rest of statements in this procedure

    for( iPos = 1 ; iPos <= max_position ; iPos++)
    {

      int magic_number = MagicNumberTable( Symbol() , iPos );
      //-- Check first position --> P1

      if( iPos == 1 )
      {

          if( FindThenSelectOpenOrder( magic_number , ticket )  )
          //-- the FindThenSelectOpenOrder returns ticket by reference
          {
            Print(  "[Execute_Entry_Sell_PMultiple] @ iPos-" , IntegerToString( iPos ) ,
              " Position P1 exists.",
              " Ticket #" , IntegerToString(ticket) ,
              " Execute_Entry_Sell_PMultiple considers next position/s." ) ;

            // Position 1 exists, not closed, go to the next loop to consider next position
            // iPos will be raised to 2 in the next loop
            continue;
          }

          break;    //-- exit this loop, execute the selling

      } //-- if( iPos == 1 )
      else    //-- iPos > 1
      {

         // Print(  "[Execute_Entry_Sell_PMultiple] @ iPos: " , IntegerToString( iPos ) ,
              // " **** DEBUGGING ****") ;

         // FINDING - DEBUGGING
         // The issue is iPos is raised to check subsequent pyramiding
         // the raised iPos value goes to the max_position
         // Delete this later
         // Solution: pick the iPos for opened position as lastPos
         // then, use lastPos+1 for the next pyramid position




          // Current position MUST NOT EXIST
          // ALL Previous positions MUST EXIST
          // ALL Previous positions MUST in PROFIT

          magic_number = MagicNumberTable( Symbol() , iPos );

          if( FindThenSelectOpenOrder( magic_number , ticket ) == false  )
          {
            Print(  "[Execute_Entry_Sell_PMultiple] @ iPos-" , IntegerToString( iPos ) ,
              " Position P" , IntegerToString(iPos) , " NOT EXIST.",
              " Ticket #" , IntegerToString(ticket) ,
              " Execute_Entry_Sell_PMultiple considers next position/s."  ,
              " BREAK from the loop at iPos=" , iPos
              ) ;

            // Position iPos not exists, not closed, go to the next loop to consider next position
            // iPos count stops here
            break;
          }
          else
          {
            Print("[Execute_Entry_Sell_PMultiple] @ iPos-" , IntegerToString( iPos ) ,
              " Position P" , IntegerToString(iPos) , " EXISTs.",
              " Ticket #" , IntegerToString(ticket) ,
              " Execute_Entry_Sell_PMultiple continue the loop." ) ;
          }

      } //-- End of else if( iPos > 1 )

    } //-- End of for(int iPos = 1 ; iPos <= max_position ; iPos++)





    //-- Check all previous position MUST EXIST
    //-- Done by previous loop (IMPLICITLY)

    //-- Check all previous position MUST IN PROFIT
    //-- Start from the most recent previous position
    for( int j=iPos-1 ; j >= 1 ; j-- )
    {
      int magic_number = MagicNumberTable( Symbol() , j );
      if( FindThenSelectOpenOrder( magic_number , ticket ) )
      {
        if ( OrderProfit() <= 0.01 )
        {
          // Print("[Execute_Entry_Sell_PMultiple] @ Pos: " , IntegerToString( j ) ,
                // " Position P" , IntegerToString(j) , " with ticket #",ticket," is NOT PROFITABLE",
                // " so that, CANCEL adding position for P" , iPos
                // ) ;

          Print("[Execute_Entry_Sell_PMultiple]: " ,
                " Cancel adding new position P" , iPos ,
                ", because previous position P",  j ," is NOT PROFITABLE."
                " Position P",j,"'s ticket is #" , ticket
                );

          // previous position MUST be profitable, otherwise exit procedure
          return ;
        }
      } // End of if( FindThenSelectOpenOrder( magic_number , ticket ) )

    } // End of for( int j=iPos-1 ; j >= 1 ; j-- )




    //+-----------------------------------------------------------------+
    //| iPos# < max_position                                            |
    //+-----------------------------------------------------------------+

    int magic_number = MagicNumberTable( Symbol() , max_position );
    if( FindThenSelectOpenOrder( magic_number , ticket ) )
    {
      Print("[Execute_Entry_Sell_PMultiple] @ Pos: " , IntegerToString( max_position ) ,
            " MAX Position P" , IntegerToString(max_position) , " exist.",
            " Ticket #" , IntegerToString(ticket) ,
            " so that, NO MORE adding position."
            ) ;
      return;
    }






    //+-----------------------------------------------------------------+
    //| DailyCountEntry MUST be < DailyEntryMax                         |
    //+-----------------------------------------------------------------+

    if ( DailyCountEntry >=  DailyEntryMax)
    {
      Print("[Execute_Entry_Sell_PMultiple] @ iPos: " , IntegerToString( iPos ) ,
            " DailyCountEntry is " , IntegerToString(DailyCountEntry) ,
            " Entry is cancelled due to daily limit of ",DailyEntryMax," has been filled."
            );
      return;
    }




    //*******************************************************************
    //| Execute SELL iPos                                               |
    //*******************************************************************
    //- Core action for selling


    double  plannedStop     = Ask + NATR * atr_1 ;

    if( (NATR * atr_1) > CapOnStopDistancePips * Point * PointToPrice )    // Cap stop distance
      {
        plannedStop = Ask + CapOnStopDistancePips * Point * PointToPrice ;
        Print("[Execute_Entry_Sell_PMultiple]:" ,
              " ----> CAP Distance ", DoubleToString(CapOnStopDistancePips , 0)," pips is reached" ,
              " planned stop = " , DoubleToString(plannedStop , 4)
             );
      }

    double                  priceBid        = Bid;        
    ENUM_TRADEDIRECTION     direction       = DIR_SELL ;



    //------------------------------------------------------------------
    //-- Risk per trade markups
    //-- Pos 1: + 0.5% , Pos 2: +0.5%, Pos 3: +0.5%, 4 beyond: no markup
    //------------------------------------------------------------------

    double risk_markup = 0.0;

    if( RiskBooster == true )
    //-- Give a booster to the risk per trade for more position sizing
    {

        switch( iPos )
        {
          case 1: risk_markup = 1.0 / 100.0 ; break;    //-- mark up by adding +1.0%
          case 2: risk_markup = 0.5 / 100.0 ; break;    //-- mark up by adding +0.5%
          case 3: risk_markup = 0.5 / 100.0 ; break;    //-- mark up by adding +0.5%
          default: risk_markup = 0.0        ; break;
        } //-- switch( iPos )

    } //-- if( RiskBooster == true )


    double risk_per_trade = ( RiskPerTrade + risk_markup ) ;

    //-- Complete risk per trade calculation


    double lots_position = LotSize( priceBid , plannedStop , direction , risk_per_trade );

    if( !HiddenStopLossTarget )
    {

      ticket = OrderSend(
                      Symbol()
                  ,   OP_SELL
                  ,   lots_position
                  ,   priceBid
                  ,   3
                  ,   plannedStop
                  ,   TargetPriceCommon     // TargetPriceCommon is calculated on OnInit()
                  ,   "Entry Sell Signal #: " + IntegerToString( EntrySignalCountSell )
                      + " Cmnt: " + comment_for_ticket
                  ,   MagicNumberTable( Symbol() , iPos )
                  ,   0
                  ,   clrGreen
                  );

    }   // End of if( !HiddenStopLossTarget )
    else
    {

      //-- Resize the PositionTracker to fit just the position; not excessive
      //-- So that, we can use ArrayRange() to focus on the position number
      // ArrayResize( PositionTracker , iPos ) ;

      //- Resetting the record
      PositionTracker[iPos].Ticket      = 0       ;
      PositionTracker[iPos].PositionSequence = 0  ;
      PositionTracker[iPos].openPrice   = 0.0     ;   //-- This is not actual entry price
      PositionTracker[iPos].SL          = 0.0     ;
      PositionTracker[iPos].TP          = 0.0     ;
      PositionTracker[iPos].openTime    = 0       ;
      PositionTracker[iPos].magicNumber = 0       ;
      PositionTracker[iPos].MarkedToClose = false ;

      //-- Open the order
      ticket = OrderSend(
                      Symbol()
                  ,   OP_SELL
                  ,   lots_position
                  ,   priceBid
                  ,   3
                  ,   0           //--  plannedStop is set to 0
                  ,   0           //-- TargetPriceCommon
                  ,   "Entry Sell Signal #: " + IntegerToString( EntrySignalCountSell )
                      + " Cmnt: " + comment_for_ticket
                  ,   MagicNumberTable( Symbol() , iPos )
                  ,   0
                  ,   clrGreen
                  );

      //-- Record tracker for the position
      PositionTracker[iPos].Ticket        = ticket            ;
      PositionTracker[iPos].PositionSequence = iPos           ;
      PositionTracker[iPos].openPrice     = priceBid          ;   //-- This is not actual entry price
      PositionTracker[iPos].SL            = plannedStop       ;
      PositionTracker[iPos].TP            = TargetPriceCommon ;
      PositionTracker[iPos].openTime      = Time[0]           ;
      PositionTracker[iPos].magicNumber   = MagicNumberTable( Symbol() , iPos ) ;
      PositionTracker[iPos].MarkedToClose = false ;
      //-- NOTE for peace of mind, see again Lucas Liew course
      //-- for part of hidden stop and hidden target


    } // End of ELSE on if( !HiddenStopLossTarget )


      //*****************//
      //*** DEBUGGING ***//
      //*****************//
      Print("");
      Print("***********************************");
      Print(
              "[Execute_Entry_Sell_PMultiple]:"
            , " iPos : "          , IntegerToString(iPos)
            , " Ticket: #"        , IntegerToString(ticket)
            , " Bid: "            , DoubleToString(priceBid ,2)   //-- Actual entry price available in the next tick !!
            , " NATR: "           , DoubleToString(NATR ,1)
            , " atr_1: "          , DoubleToString(atr_1 ,5)
            , " atr_1 pips: "     , DoubleToString((atr_1 / (Point * PointToPrice) ) ,0)
            , " Distance NATR: "       , DoubleToString( NATR * atr_1 , 5)
            , " Distance NATR pips: "  , DoubleToString( (NATR * atr_1)/(Point * PointToPrice) ,0)
            , " Distance Actual pips: " , DoubleToString( (plannedStop - priceBid ) / (Point * PointToPrice) ,0  )
            , " Plan Tgt Price: " , DoubleToString( TargetPriceCommon , 2 )
            , " Plan Target Pips: ",  DoubleToString( (priceBid - TargetPriceCommon)/(Point * PointToPrice) , 0)
            , " Lot: "            , DoubleToString( lots_position , 2)
            , " Risk Per Trade: " , DoubleToString( (risk_per_trade * 100.0) , 2 ) , "%"
          );
      Print("***********************************");
      Print("");

      //-- NOTE: Actual entry price only available in the next tick !


    if(ticket < 0)
      {

        //-- Entering SELL FAILED

        int _errNumber = GetLastError();
        Alert("[Execute_Entry_Sell_PMultiple]: " ,
              " iPos#: "          , IntegerToString(iPos) ,
              " Error Sending Order SELL!" ,
              " Error Number: "      , IntegerToString( _errNumber ) ,
              " Error Description: " , GetErrorDescription( _errNumber )
              );

      }
    else
    {

        //-- Entering SELL SUCCESSFUL

        // increase daily count entry after entry
        DailyCountEntry++ ;

            //-- DEBUGGING
            if( DailyCountEntry >= DailyEntryMax )
            {
              Print("[Execute_Entry_Sell_PMultiple]:" ,
                    " iPos#: "          , IntegerToString(iPos) ,
                    " REACHED MAX DAILY ENTRY."   ,
                    " DailyCountEntry: " , IntegerToString(DailyCountEntry)
                   );
            }


        // mark the order is opened
        // flag_OrderOpen[iPos] = true ;

        // mark closed by technical analysis is false
        // closedByTechnicalAnalysis = false ;

        // RESET Trade profit threshold flag
        TradeFlag_ProfitThresholdPassed = false ;


        //--------------
        //-- DEBUGGING
        //--------------

        Print("[Execute_Entry_Sell_PMultiple]:" ,
              " DEBUGGING - iPos#: "          , IntegerToString(iPos)
            );

        // RESET Breakeven_iPos_Applied
        Breakeven_iPos_Applied[iPos] = false ;

        // RESET ProfitLock250Pips_iPos_Applied
        ProfitLock250Pips_iPos_Applied[iPos] = false ;

        int _errNumber = GetLastError();
        if( _errNumber > 0 )
        {
          Print("[Execute_Entry_Sell_PMultiple]:" ,
              " iPos#: "          , IntegerToString(iPos) ,
              " Error #" , IntegerToString(_errNumber) ,
                ": " , GetErrorDescription(_errNumber)
            );
        } // End of if( _errNumber > 0 )






      //------------------------------------------------------------------
      //-- Calculate entry price distance in pips between P1, P2, P3, ...
      //------------------------------------------------------------------

      if( iPos > 1)
      {
        int     mn_curr   ;   // Magic Numbers
        int     mn_prev   ;
        int     mn_first  ;

        int     tk_curr   ;   // Tickets
        int     tk_prev   ;
        int     tk_first  ;

        double  opnprice_curr   ;
        double  opnprice_prev   ;
        double  opnprice_first   ;


        //-- Find the open price for the first position
        mn_first = MagicNumberTable( Symbol() , 1 );
        if( FindThenSelectOpenOrder( mn_first , tk_first ) )
          opnprice_first = OrderOpenPrice() ;
        else
          Print("[Execute_Entry_Sell_PMultiple]:" ,
                " *** WARNING *** P1 is NOT FOUND!! Order missing !!!"
                );


        if( iPos == 2 )
        {

          mn_curr = MagicNumberTable( Symbol() , iPos )  ;
          if( FindThenSelectOpenOrder( mn_curr , tk_curr ) )
            opnprice_curr = OrderOpenPrice() ;
          else
                Print("[Execute_Entry_Sell_PMultiple]:" ,
                      " *** WARNING *** P2 is NOT FOUND!! Order missing !!!"
                      );

          Print("[Execute_Entry_Sell_PMultiple]:" ,
                " Dist in pips P1 to P2: " ,
                    DoubleToString( (opnprice_first - opnprice_curr )/(Point * PointToPrice), 0 )
                );

        }   // End of if( iPos == 2 )
        else
        {

          for( int j=2 ; j<=iPos ; j++ )
          {

            mn_prev = MagicNumberTable( Symbol() , j-1 );
            if( FindThenSelectOpenOrder( mn_prev , tk_prev ) )
              opnprice_prev = OrderOpenPrice();
              else  Print("[Execute_Entry_Sell_PMultiple]: WARNING ORDER P", (j-1) , " NOT FOUND");

            mn_curr = MagicNumberTable( Symbol() , j );
            if( FindThenSelectOpenOrder( mn_curr , tk_curr) )
              opnprice_curr = OrderOpenPrice();
              else  Print("[Execute_Entry_Sell_PMultiple]: WARNING ORDER P", (j) , " NOT FOUND");

            Print("[Execute_Entry_Sell_PMultiple]:" ,
                  " Dist in pips P", (j-1) ," to P",j,": " ,
                      DoubleToString( (opnprice_prev - opnprice_curr)/(Point * PointToPrice), 0 )
                  );

            if( j==iPos )   //-- Final distance - P1 to the existing P
            Print("[Execute_Entry_Sell_PMultiple]:" ,
                  " Dist in pips P1 to P",j,": " ,
                      DoubleToString( (opnprice_first - opnprice_curr )/(Point * PointToPrice), 0 )
                  );

          } // End of for( int j=3 ; j<=iPos ; j++ )

        } // End of ELSE on if( iPos == 2 )


      } //-- End of if( iPos > 1)










      //*****************//
      //*** DEBUGGING ***//
      //*****************//

        //-- Add text under arrow
        string  entryDetails1 ;
        string  entryDetails2 ;
        string  entryDetails3 ;
        entryDetails1 =
                          "P"+ IntegerToString(iPos) + " Ticket #" + IntegerToString(ticket)
              + "/ \n" +  "Time: "      + TimeToStr(Time[0] , TIME_MINUTES )
              + "/ \n" +  "Bid: "       + DoubleToString(priceBid , 2)
              + "/ \n" +  "NATR: "      + DoubleToString(NATR , 1)
              ;
        entryDetails2 =
                          "ATR: "       + DoubleToString(atr_1 , 4)
              + "/ \n" +  "Stop: "      + DoubleToString(plannedStop , 2)
              + "/ \n" +  "Dist Pips: " + DoubleToString((NATR * atr_1)/(Point * PointToPrice) , 2)
              + "/ \n" +  "LotSize: "   + DoubleToString(lots_position , 4)
              ;
        entryDetails3 =
                          "Target: "    + DoubleToString(TargetPriceCommon , 2)
              + "/ \n" +  "Magic Number: " + IntegerToString(MagicNumberTable( Symbol() , iPos ))
                    ;
        string  txtName = "entdtl1 " + TimeToStr(Time[0] , TIME_DATE|TIME_MINUTES ) ;
        ObjectCreate( txtName , OBJ_TEXT , 0 , Time[0] , High[1] + 12.0 * Point );
        ObjectSetText( txtName , entryDetails1 ,9 , "Arial" , clrGreen );

                txtName = "entdtl2 " + TimeToStr(Time[0] , TIME_DATE|TIME_MINUTES ) ;
        ObjectCreate( txtName , OBJ_TEXT , 0 , Time[0] , High[1] + 16.0 * Point );
        ObjectSetText( txtName , entryDetails2 ,9 , "Arial" , clrGreen );

                txtName = "entdtl3 " + TimeToStr(Time[0] , TIME_DATE|TIME_MINUTES ) ;
        ObjectCreate( txtName , OBJ_TEXT , 0 , Time[0] , High[1] + 20.0 * Point );
        ObjectSetText( txtName , entryDetails3 ,9 , "Arial" , clrGreen );

      //*********************//
      //*** END Debugging ***//
      //*********************//


        // Initialize trading journal
        // MAEPips     = 0.0 ;
        // MFEPips     = 0.0 ;
        // RMult_Max   = 0.0 ;
        // RMult_Final = 0.0 ;

        // #TRICKY FOUND
        // RInitPips   = (OrderStopLoss() - OrderOpenPrice() ) / Point() ;
        // OrderOpenPrice() / OrderStopLoss() : 0.0 / 0.0
        // OrderOpenPrice() and OrderStopLoss() ARE AVAILABLE IN THE NEXT TICK !!!



        // Validate how much the slippage
        //if( OrderSelect(ticket for P1 , SELECT_BY_TICKET , MODE_TRADES ) == true )
        //  {
        //    double actualOpenPrice = OrderOpenPrice();
        //    Print( "SLIPPAGE TEST: Price Ask vs ActualEntry Price and difference: "
        //            , priceAsk , " / " , actualOpenPrice , " / " , (actualOpenPrice - priceAsk) );
        //  }


    } //-- Entry sell SUCCESSFUL





} //-- End of void Execute_Entry_Sell_PMultiple()






//+-------------------------------------------------------------------------------------------------+
//| Lot Sizing                                                                                      |
//+-------------------------------------------------------------------------------------------------+

double LotSize(
    double              &priceEntry ,
    double              &plannedStop ,
    ENUM_TRADEDIRECTION &direction ,
    double              risk_per_trade
    )
  {
    //double  _lots_ = AccountEquity() / 10000 * LotsPer10K ;
    //-- OVERRIDE FOR DEBUGGING
    //double _lots_ = LotsFix ;

    double  distance ;
    double  lotsize ;
    double  riskdollar ;

    // riskdollar = AccountEquity() * RiskPerTrade ;
    riskdollar = AccountEquity() * risk_per_trade ;

    if( direction == DIR_BUY )
      {
        distance    = priceEntry - plannedStop ;
      }
    else if(direction == DIR_SELL)
      {
        distance    = plannedStop - priceEntry ;
      }

    Print(    "[LotSize]:"
            , " | " , "Distance: "         ,   DoubleToStr( distance   , 4)
            , " | " , "priceEntry: "       ,   DoubleToString( priceEntry , 4 )
            , " | " , "plannedStop: "      ,   DoubleToString( plannedStop , 4)
            , " | " , "AccountEquity: "    ,   DoubleToStr(AccountEquity() , 2 )
            , " | " , "RiskDollar: "       ,   DoubleToStr(riskdollar , 2 )
            , " | " , "Risk Per Trade: "   ,   risk_per_trade

         );

    // Failsafe to prevent distance
    if(distance < 1 * Point * PointToPrice ) // if distance less than 1 pip, no trade!
      {
        lotsize = 1 ;
        Print("[LotSize]:"
            , " *** ERROR: Stoploss Distance to is ZERO ***" );
      }
    else
      {
        double riskdoloverdist ;

        riskdoloverdist = riskdollar / distance ;
        lotsize = riskdoloverdist * (10/10000.0) ;    // 100 is leverage level

        Print("[LotSize]:"
              , " | " , "Distance pips: "        , DoubleToStr( (distance / (Point * PointToPrice))  , 0)
              , " | " , "RiskDollar: "           , DoubleToString(riskdollar , 2)
              , " | " , "Distance: "             , DoubleToStr( distance   , 4)
              , " | " , "RiskdollarOverDist: "   , DoubleToStr( riskdoloverdist   , 4)
              , " | " , "LotSize: "              , DoubleToStr( lotsize  , 2)
              );

        // IMPORTANT: division on double variable MUST USE double value
        // Example:
        // WONT WORK: (1/100000)
        // WILL WORK: (1.0 / 100000)

        //Print(      "INNER IF lotsize: ", lotsize
        //        ,   " RiskDollar over Distance: " , DoubleToStr( riskdoloverdist , 2 )
        //    );
      }

    //Print( "OUTER IF lotsize: ", lotsize );
    return lotsize  ;
  }







/*/////////////////////////////////////////////////////////////////////////////////////////////////*/
/*///////////////////////////////      EXPERT OnTick FUNCTION    //////////////////////////////////*/
/*/////////////////////////////////////////////////////////////////////////////////////////////////*/



void OnTick()
  {



    /***********************************************************************************************/
    /***   STARTING BLOCK   ***/
    /***********************************************************************************************/



    //-- Timeframe controller
    static bool     IsFirstTick_TTF = false ;
    static int      TTF_Barname_Curr ;
    static int      TTF_Barname_Prev ;


    static bool     IsFirstTick_HTF = false;
    static int      HTF_Barname_Curr ;
    static int      HTF_Barname_Prev ;


    static bool     IsFirstTick_MTF = false;
    static int      MTF_Barname_Curr ;
    static int      MTF_Barname_Prev ;


    static bool     IsFirstTick_LTF = false;
    static int      LTF_Barname_Curr ;
    static int      LTF_Barname_Prev ;



    //-- Reporting controller to prevent double reporting after closed order by technical analysis
    //-- not to be reported again in the next tick after getting history pool selectorder
    static bool     closedByTechnicalAnalysis = false;


    //-- Trading Journal variables
    //-- Refer to [MVTS_4_HFLF_Model_A.mq4] for Trading Journal Variables

        /*---------------------------------------------------------------------------------*\
        | *)    "In fact, another definition of expectancy is the average R-value of the
        |       system." Van Tharp [2008], p.19, "Definitive Guide to Position Sizing"
        \*---------------------------------------------------------------------------------*/

    //-- Equity Drawdown Variables
    static double   InitialEquity       = AccountEquity() ;
    static double   PeakEquity          = AccountEquity() ;
    static double   DrawdownEquity      = 0.0 ;
    static double   DrawdownPercent     = 0.0 ;
    static double   DrawdownMaxEquity   = 0.0 ;
    static double   DrawdownMaxPercent  = 0.0 ;
    static double   RecoveryRatio       = 0.0 ;

    //-- ICAGR / ACAGR / MAR / PDD / FREQUENCY
    //-- ICAGR is for annual return. Here it is replaced with
    //-- quarterly timeframe, hence ICQGR
    //-- Instantaneously Compounded Quarterly Growth Rate


    // Counter for tick per hour
    static int      TickCountPerHour = 0 ;


    //-- Warning Controller

    // Preventing printing equity level more than once
    static bool     InvalidEquityLevel = false ;



    //--- Comment for exit
    string comment_exit ;


    /***********************************************************************************************/
    /***   BLOCK TO PREVENT NON-VALID LOGIC   ***/
    /***********************************************************************************************/


    // if( MA_Fast >= MA_Slow )
    // {
    // return;
    // }


   //-- Invalid Equity Level

   if( AccountEquity() < 100 && InvalidEquityLevel == false )
     {
        // Preventing printing equity level more than once
        InvalidEquityLevel = true;

        Print(
            "WARNING: AccountEquity() < 100. Account Equity is $" , DoubleToStr( AccountEquity() , 2 )
            );

        return;
     }




    /***********************************************************************************************/
    /***   BLOCK TO OPERATE ON FIRST TICK OF EACH TIME FRAME   ***/
    /***********************************************************************************************/

    /*
    Fundamental code for multiple timeframe
    */

    /*
    Pick the higher timeframe
    */





    //+---------------------------------------------------------------------------------------------+
    //| TICK BY TICK MONITORING                                                                     |
    //+---------------------------------------------------------------------------------------------+


    // Track_TradingJournal_Vars( MAEPips , MFEPips , RInitPips , RMult_Max , RMult_Final );

    Track_EquityPeakAndDrawdown(
          InitialEquity  ,
          PeakEquity ,
          DrawdownEquity ,
          DrawdownPercent ,
          DrawdownMaxEquity ,
          DrawdownMaxPercent ,
          RecoveryRatio
          );


    // Increase tick count per HOUR (MTF)
    TickCountPerHour++ ;





    //+---------------------------------------------------------------------------------------------+
    //| HIDDEN STOP AND HIDDEN TARGET                                                               |
    //+---------------------------------------------------------------------------------------------+

    // Hidden Stop and Hidden Target works at the very first of tick available


    if( HiddenStopLossTarget )
    {

      int     positionTotal   = OrdersTotal();
      double  stoploss ;
      double  targetprofit ;
      bool    doesPositionListExists ;
      int     magic_number ;

      /*-----------------------------------------------------------------------------------*/
      /****** 1. MONITOR STOP LOSS ******/
      /*-----------------------------------------------------------------------------------*/


      //-- for each position, get its stop loss in the list, and put a marker
      //-- then, using the marker, loop again each loop, find the marked to close,
      //-- use the ticket, close the position

      for(int i=0 ; i < positionTotal ; i++ )
      {

            //-- select the order
            bool  resultselect = OrderSelect( i , SELECT_BY_POS , MODE_TRADES );
            int   ticketpos = OrderTicket();
            magic_number = OrderMagicNumber();

            //-- Failsafe practice in case resultselect not pick
            if (!resultselect)
            {
              string _errMsg ;
                _errMsg = "[OnTick]>(Tick by tick monitoring): "
                          + "Failed to select order for marking in "
                          + "Stop Loss Monitoring. Error: "
                          + GetLastError() ;
              Print( _errMsg );
              Alert( _errMsg );
              Sleep(3000);
            } // End of if (!resultselect)
            else
            //-- Position is found
            //-- Proceed to evaluate stop loss
            {


              //-- get the SL by matching the ticket

              doesPositionListExists = false;
              int iPos ;
              for(iPos=1 ; iPos<=MaxPositions ; iPos++ )
              {
                if( PositionTracker[iPos].Ticket == ticketpos )
                {
                  stoploss = PositionTracker[iPos].SL ;
                  doesPositionListExists = true ;

                  //-- check the SL if it is breached. Mark the the order to close
                  if( OrderType() == OP_BUY && stoploss >= Bid )
                      PositionTracker[iPos].MarkedToClose = true ;
                  if( OrderType() == OP_SELL && stoploss <= Ask )
                      PositionTracker[iPos].MarkedToClose = true ;
                  //-- break from PositionTracker loop, proceed to the next position

                  break;

                } // End of if( PositionTracker[iPos].Ticket = OrderTicket() )
              }   // End of for( iPos=1 ; iPos<=MaxPositions ; iPos++ )

                  // no list
                  if (doesPositionListExists==false && iPos == (MaxPositions+1) )
                  //-- The iPos loop has been looped completely, BUT,
                  //-- doesPositionListExists is still FALSE
                  {
                      //-- SEND NOTIFICATION POSITION LIST IS NOT EXIST

                      Print("");
                      Print("[OnTick]: ***>>> STOPLOSS EVALUATION"
                          " Position with ticket #" , ticketpos ,
                          " Magic Number: " , magic_number ,
                          " have NO LIST !!!"
                            );
                      Print("");

                  } // End of if (doesPositionListExists==false)
            } // End of ELSE on if (!resultselect)

      } // End of for(i=1 ; i <= positionTotal ; i++ )



      //-- Loop through all the list, find those marked, and close position if marked to close
      for(int iPos=1 ; iPos <= MaxPositions ; iPos++ )
      {


        // Check the MarkedToClose
        if( PositionTracker[iPos].MarkedToClose == true )
        {
          // Use the ticket # to select order
          if( OrderSelect( PositionTracker[iPos].Ticket , SELECT_BY_TICKET , MODE_TRADES  ) == true )
          {
            if( OrderType() == OP_BUY )
            {
                // Close the selected order
                if ( OrderClose( PositionTracker[iPos].Ticket, OrderLots(),
                      MarketInfo(OrderSymbol(), MODE_BID), 5, Red ) == true )
                {

                  // Set the list to zero
                  PositionTracker[iPos].Ticket      = 0       ;
                  PositionTracker[iPos].PositionSequence = 0  ;
                  PositionTracker[iPos].openPrice   = 0.0     ;   //-- This is not actual entry price
                  PositionTracker[iPos].SL          = 0.0     ;
                  PositionTracker[iPos].TP          = 0.0     ;
                  PositionTracker[iPos].openTime    = 0       ;
                  PositionTracker[iPos].magicNumber = 0       ;
                  PositionTracker[iPos].MarkedToClose = false ;
                  //-- The position is set to zero to avoid confusion with profit target monitor


                  // Log the closing
                  Print("");
                  Print("[OnTick]: HIDDEN STOP LOSS IS EXECUTED!",
                        " Ticket: #" , IntegerToString(OrderTicket()) , " is closed." ,
                        " Position P", iPos
                        );
                  Print( "[OnTick]: STOP LOSS EXECUTION ORDER:" ,
                        " OpenPrice(): " ,      DoubleToString( OrderOpenPrice() ,2 )   ,
                        " ClosedPrice(): " ,    DoubleToString( OrderClosePrice() ,2 )  ,
                        " OrderProfit PIPS: " ,
                            DoubleToString( ( OrderClosePrice()-OrderOpenPrice() ) / (Point * PointToPrice)
                              ,0 )  ,
                        " OrderCloseTime():",   OrderCloseTime() ,
                        " OrderProfit(): " ,    DoubleToString(OrderProfit() , 2)
                        );
                  Print("");

                } // End of OrderClose()
              else
                Print("[OnTick]: ****>>>" ,
                  " Failed to select order #", PositionTracker[iPos].Ticket ," to close."
                  " Order is not closed."
                  );

            } // End of if( OrderType() == OP_BUY )
            else if (OrderType() == OP_SELL )
            {

                if ( OrderClose( PositionTracker[iPos].Ticket, OrderLots(),
                      MarketInfo(OrderSymbol(), MODE_ASK), 5, Red ) == true )
                {

                  // Set the list to zero
                  PositionTracker[iPos].Ticket      = 0       ;
                  PositionTracker[iPos].PositionSequence = 0  ;
                  PositionTracker[iPos].openPrice   = 0.0     ;   //-- This is not actual entry price
                  PositionTracker[iPos].SL          = 0.0     ;
                  PositionTracker[iPos].TP          = 0.0     ;
                  PositionTracker[iPos].openTime    = 0       ;
                  PositionTracker[iPos].magicNumber = 0       ;
                  PositionTracker[iPos].MarkedToClose = false ;
                  //-- The position is set to zero to avoid confusion with profit target monitor


                  // Log the closing
                  Print("");
                  Print("[OnTick]: HIDDEN STOP LOSS IS EXECUTED!",
                        " Ticket: #" , IntegerToString(OrderTicket()) , " is closed." ,
                        " Position P", iPos
                        );
                  Print( "[OnTick]: STOP LOSS EXECUTION ORDER:" ,
                        " OpenPrice(): " ,      DoubleToString( OrderOpenPrice() ,2 )   ,
                        " ClosedPrice(): " ,    DoubleToString( OrderClosePrice() ,2 )  ,
                        " OrderProfit PIPS: " ,
                            DoubleToString( ( OrderOpenPrice() - OrderClosePrice() ) / (Point * PointToPrice)
                              ,0 )  ,
                        " OrderCloseTime():",   OrderCloseTime() ,
                        " OrderProfit(): " ,    DoubleToString(OrderProfit() , 2)
                        );
                  Print("");

                } // End of OrderClose()
              else
                Print("[OnTick]: ****>>>" ,
                  " Failed to select order #", PositionTracker[iPos].Ticket ," to close."
                  " Order is not closed."
                  );
            } // End of else if (OrderType() == OP_SELL )
            else
            {
              Print("[OnTick] >> Hidden StopLoss >>" ,
                " Ticket #", PositionTracker[iPos].Ticket ," is not OP_BUY nor OP_SELL."
                " Order is not closed."
                );
            } // End of ELSE on else if (OrderType() == OP_SELL )

          } // End if( OrderSelect( PositionTracker[iPos].Ticket , SELECT_BY_TICKET ...

        } // End if( PositionTracker[iPos].MarkedToClose == true )


      } // End of for(int iPos=1 ; iPos <= MaxPositions ; iPos++ )




      /*-----------------------------------------------------------------------------------*/
      /****** 2. MONITOR TARGET ******/
      /*-----------------------------------------------------------------------------------*/

      /*
        - For each position, check accompanying PositionTracker
        - Compare PositionTracker's profit target with BID for OP_BUY
        - Mark the PositionTracker.MarkedToClose for closing if target met

        - For each item in PositionTracker, check the MarkedToClose
        - Find the order by ticket if MarkedToClose is true
          - If ticket is not found (very unlikely), raise error, raise notification
        - Close the order by ticket

      */


      //-- pick the latest positionTotal (after some closure in the stop loss above)
      positionTotal   = OrdersTotal();

      //-- For each position, check accompanying PositionTracker
      for ( int i=0 ; i < positionTotal ; i++ )
      {

        bool  resultselect  = OrderSelect( i , SELECT_BY_POS , MODE_TRADES );
        int   ticketpos     = OrderTicket();
        magic_number        = OrderMagicNumber();

        if( resultselect==true )
        {

          doesPositionListExists    = false ;
          int iPos ;
          for( iPos = 1 ; iPos <= MaxPositions ; iPos++ )
          {

            if( PositionTracker[iPos].Ticket == ticketpos )
            {
              // found the tracker
              // now get the profit target
              targetprofit = PositionTracker[iPos].TP ;
              doesPositionListExists  = true;

              // check Bid price (for OP_BUY) against targetprofit
              if( OrderType()==OP_BUY && Bid >= targetprofit )
              {
                PositionTracker[iPos].MarkedToClose = true ;
              } // End of if( OrderType()==OP_BUY && Bid >= targetprofit )

              // check Bid price (for OP_BUY) against targetprofit
              if( OrderType()==OP_SELL && Ask <= targetprofit )
              {
                PositionTracker[iPos].MarkedToClose = true ;
              } // End of if( OrderType()==OP_BUY && Bid >= targetprofit )

              //-- break from PositionTracker loop
              break;

            } // End of if( PositionTracker[iPos].Ticket == ticketpos )
          } // End of for( iPos = 1 ; iPos <= MaxPositions ; iPos++ )

          // Position is not found in the list
          if( iPos == (MaxPositions+1) && doesPositionListExists==false )
          {
                      //-- SEND NOTIFICATION POSITION LIST IS NOT EXIST

                      Print("");
                      Print("[OnTick]: ***>>> TARGETPROFIT EVALUATION"
                          " Position with ticket #" , ticketpos ,
                          " Magic Number: " , magic_number ,
                          " have NO LIST !!!"
                            );
                      Print("");

          } // End of if( iPos == (MaxPositions+1) && doesPositionListExists==false )


        } // End of if( resultselect==true )
        else
        {
              string _errMsg ;
                _errMsg = "[OnTick]>(Tick by tick monitoring): "
                          + "Failed to select order for marking in "
                          + "Profit Target. Error: "
                          + GetLastError() ;
              Print( _errMsg );
              Alert( _errMsg );
              Sleep(3000);
        } // End of ELSE on if( resultselect==true )
      }   // End of for ( int i=0 ; i < positionTotal ; i++ )



      //-- for each item in PositionTracker, check the MarkedToClose
      //-- and close the position if MarkedToClose is true
      for( int iPos = 1 ; iPos <= MaxPositions ; iPos ++ )
      {

        // Check the MarkedToClose
        if( PositionTracker[iPos].MarkedToClose == true )
        {
          // Use the ticket # to select order
          if( OrderSelect( PositionTracker[iPos].Ticket , SELECT_BY_TICKET , MODE_TRADES  ) == true )
          {


            if( OrderType() == OP_BUY )
            {
                // Close the selected order
                if ( OrderClose( PositionTracker[iPos].Ticket, OrderLots(),
                      MarketInfo(OrderSymbol(), MODE_BID), 5, Red ) == true )
                {

                  // Set the list to zero
                  PositionTracker[iPos].Ticket      = 0       ;
                  PositionTracker[iPos].PositionSequence = 0  ;
                  PositionTracker[iPos].openPrice   = 0.0     ;   //-- This is not actual entry price
                  PositionTracker[iPos].SL          = 0.0     ;
                  PositionTracker[iPos].TP          = 0.0     ;
                  PositionTracker[iPos].openTime    = 0       ;
                  PositionTracker[iPos].magicNumber = 0       ;
                  PositionTracker[iPos].MarkedToClose = false ;
                  //-- The position is set to zero to avoid confusion with profit target monitor


                  // Log the closing
                  Print("[OnTick]: HIDDEN TARGET PROFIT IS EXECUTED!",
                        " Ticket: #" , IntegerToString(OrderTicket()) , " is closed." ,
                        " OpenPrice(): " ,      DoubleToString( OrderOpenPrice() ,2 )   ,
                        " ClosedPrice(): " ,    DoubleToString( OrderClosePrice() ,2 )  ,
                        " OrderProfit PIPS: " ,
                            DoubleToString( ( OrderClosePrice()-OrderOpenPrice() ) / (Point * PointToPrice)
                              ,0 )  ,
                        " OrderCloseTime():",   OrderCloseTime() ,
                        " OrderProfit(): " ,    DoubleToString(OrderProfit() , 2)
                        );
                        
                  // LOGIC #2 When Position #1 hits PROFIT TARGET 
                  // Tag for Large Profit
                  if  (iPos == 1)
                  {
                    TradeFlag_ClosedOnBigProfit = true ;
                    Print("[OnTick]: HIDDEN TARGET PROFIT with TradeFlag_ClosedOnBigProfit = true" );
                  }

                } // End of OrderClose()

            } // End if( OrderType() == OP_BUY )
            else if  ( OrderType() == OP_SELL )
            {
                // Close the selected order
                if ( OrderClose( PositionTracker[iPos].Ticket, OrderLots(),
                      MarketInfo(OrderSymbol(), MODE_ASK), 5, Red ) == true )
                {

                  // Set the list to zero
                  PositionTracker[iPos].Ticket      = 0       ;
                  PositionTracker[iPos].PositionSequence = 0  ;
                  PositionTracker[iPos].openPrice   = 0.0     ;   //-- This is not actual entry price
                  PositionTracker[iPos].SL          = 0.0     ;
                  PositionTracker[iPos].TP          = 0.0     ;
                  PositionTracker[iPos].openTime    = 0       ;
                  PositionTracker[iPos].magicNumber = 0       ;
                  PositionTracker[iPos].MarkedToClose = false ;
                  //-- The position is set to zero to avoid confusion with profit target monitor


                  // Log the closing
                  Print("[OnTick]: HIDDEN TARGET PROFIT IS EXECUTED!",
                        " Ticket: #" , IntegerToString(OrderTicket()) , " is closed." ,
                        " OpenPrice(): " ,      DoubleToString( OrderOpenPrice() ,2 )   ,
                        " ClosedPrice(): " ,    DoubleToString( OrderClosePrice() ,2 )  ,
                        " OrderProfit PIPS: " ,
                            DoubleToString( ( OrderOpenPrice()-OrderClosePrice() ) / (Point * PointToPrice)
                              ,0 )  ,
                        " OrderCloseTime():",   OrderCloseTime() ,
                        " OrderProfit(): " ,    DoubleToString(OrderProfit() , 2)
                        );

                  // LOGIC #2 When Position #1 hits PROFIT TARGET 
                  // Tag for Large Profit
                  if  (iPos == 1)
                  {
                    TradeFlag_ClosedOnBigProfit = true ;
                    Print("[OnTick]: HIDDEN TARGET PROFIT with TradeFlag_ClosedOnBigProfit = true" );
                  }                        

                } // End of OrderClose()

            } // End else if  ( OrderType() == OP_SELL )
            else
            {
                Print("[OnTick] >> Hidden Target Profit >>" ,
                  " Ticket #", PositionTracker[iPos].Ticket ," is not OP_BUY nor OP_SELL."
                  " Order is not closed."
                  );
            } // End of ELSE on else if  ( OrderType() == OP_SELL )





          } // End of if( OrderSelect( PositionTracker[iPos].Ticket ... )
          else
          {
            Print("[OnTick]: ****>>>" ,
                  " Failed to select order #", PositionTracker[iPos].Ticket ," to close."
                  " Order is not closed."
                  );
          }

        } // End if( PositionTracker[iPos].MarkedToClose == true )

      } // End of for( int iPos = 1 ; iPos <= MaxPositions ; iPos ++ )

    } // End if( HiddenStopLossTarget )





    //+---------------------------------------------------------------------------------------------+
    //| MARK EXCLUSION IN ADVANCE ZONE                                                              |
    //+---------------------------------------------------------------------------------------------+

    // Avoid events:
    //  1. CHF unpegging
    //  2. BREXIT

    //
    // ExclZone_DayBefore ExclZone_DayAfter

    ExclZone_In =
      (
      ( StringToTime(ExclZone_Date) - ExclZone_DayBefore * _DAYSECONDS_ )  <= TimeCurrent()
      &&
      TimeCurrent() <= (StringToTime(ExclZone_Date) + ExclZone_DayAfter * _DAYSECONDS_ ) )

      &&
      (
          // Exclude for the intended currency
          StringFind( Symbol() , ExclZone_Currency , 0 ) >= 0
          // IMPORTANT: StringFind returns -1 if string is not found, hence ">=0" as criteria
      )
      ;

    if( ExclZone_In )
    {
      // Close all open position
      // Print(ExclZone_Currency +  " location: " + StringFind( Symbol() , ExclZone_Currency , 0 ) );
      Print( "[OnTick]: " ,
          "THIS IS EXCLUSION ZONE. ALL OPEN POSITIONS MUST BE CLOSED. " +
          "NO NEW POSITION TO ENTER for " + ExclZone_Currency
          );
    }

    //-- Print up Hello World from MQH
    if( IsFirstTick_TTF )
    {
          mqhHelloWorld(); //-- Call the MQH Top Time Frame
          Print( "[OnTick]: This is to test Time Differences");
          Print( "[OnTick]>[WeeklyBar]: TimeCurrent : " , TimeToStr( TimeCurrent(), TIME_DATE|TIME_MINUTES ) );
          Print( "[OnTick]>[WeeklyBar]: TimeLocal   : " , TimeToStr( TimeLocal()  , TIME_DATE|TIME_MINUTES ) );
          Print( "[OnTick]>[WeeklyBar]: TimeGMT     : " , TimeToStr( TimeGMT()    , TIME_DATE|TIME_MINUTES ) );
          Print("");
    }

    //+---------------------------------------------------------------------------------------------+
    //| SELECT THE FIRST TICK OF TTF (Top Time Frame)                                               |
    //+---------------------------------------------------------------------------------------------+
    datetime  ThisTime = TimeCurrent();
    int iDay  = ( TimeDayOfWeek(ThisTime) ) % 7 + 1;              // convert day to standard index (1=Mon,...,7=Sun)
    int iWeek = ( TimeDayOfYear(ThisTime) - iDay + 10 ) / 7;      // calculate standard week number
    //-- https://www.mql5.com/en/forum/129771/page2

    TTF_Barname_Curr = iWeek ;
    if( TTF_Barname_Curr != TTF_Barname_Prev )
    {
      IsFirstTick_TTF = true ;
    }
    else
    {
      IsFirstTick_TTF = false ;
    }




    //+---------------------------------------------------------------------------------------------+
    //| SELECT THE FIRST TICK OF HTF                                                                |
    //+---------------------------------------------------------------------------------------------+


    HTF_Barname_Curr = Day();
    if(HTF_Barname_Curr != HTF_Barname_Prev )
     {
        IsFirstTick_HTF = true ;
     }
    else
     {
        IsFirstTick_HTF = false ;
     }

    /*
    When HTF_Barname_Curr = HTF_Barname_Prev, IsFirstTick_HTF = FALSE !!
    */





    //+---------------------------------------------------------------------------------------------+
    //| SELECT THE FIRST TICK OF DAILY BAR AND PROCEED THE FLOW AT FIRST (OPENING BAR) TICK ONLY    |
    //+---------------------------------------------------------------------------------------------+

    if( IsFirstTick_HTF )
    {

    // Draw vertical line
    // ==========================================

    string theDayTme = TimeToStr( Time[0] , TIME_DATE|TIME_MINUTES ) ;
    string VlineName = "VL" + theDayTme ;

    VLineCreate(0, VlineName , 0 , 0 , clrBlueViolet , STYLE_SOLID , 1 , false, false, true , 0) ;

    // Add description
    ObjectSetText( VlineName , "Line for: " + theDayTme , 9 , "Arial" , clrBlueViolet );



    // Add text
    // ---------------------------------------------------

    //--- reset the error value
    ResetLastError();

    string txtName = "TXT" + theDayTme ;
    double verticalOffset = Point * 10.0 * 5.0 ;


    //--- create Text object

    ObjectCreate( txtName , OBJ_TEXT , 0 , Time[0] , Close[1] + verticalOffset );
    ObjectSetText( txtName , DayOfWeekString( DayOfWeek() ) ,9 , "Arial" , clrRed );
    ObjectSet( txtName , OBJPROP_ANGLE , 90.0 );


    }





    //+---------------------------------------------------------------------------------------------+
    //| SELECT THE FIRST TICK OF MTF                                                                |
    //+---------------------------------------------------------------------------------------------+

    /*
    Control the timing on Hourly bar
    Exit procedure if the current tick is not the FIRST TICK OF LOWEST TIMEFRAME
    */



    MTF_Barname_Curr = Hour() ;

    if(MTF_Barname_Curr != MTF_Barname_Prev )
     {
        IsFirstTick_MTF = true ;
     }
    else
     {
        IsFirstTick_MTF = false ;
     }

    /*
    When MTF_Barname_Curr = MTF_Barname_Prev , IsFirstTick_MTF  = FALSE !!
    */







    //+---------------------------------------------------------------------------------------------+
    //| SELECT THE FIRST TICK OF LTF AND PROCEED THE FLOW AT FIRST (OPENING BAR) TICK ONLY          |
    //+---------------------------------------------------------------------------------------------+

    /*
    Control the timing on Hourly bar
    Exit procedure if the current tick is not the FIRST TICK OF LOWEST TIMEFRAME
    */



    LTF_Barname_Curr = (Minute() / 5) * 5 ;
    // The nature of integer division is like "FLOOR" function 6 / 5 = 1
    // The formula forces the value 0 , 5 , 10 , 15 ... 55


    if(LTF_Barname_Curr != LTF_Barname_Prev )
     {
        IsFirstTick_LTF = true ;
     }
    else
     {
        IsFirstTick_LTF = false ;
     }

    if( !IsFirstTick_LTF )
     {

        /*******************************************************************************************/
        /***   ENDING BLOCK OF ONTICK()   ***/
        /*******************************************************************************************/

        // This line is to ensure previous bar name carries LTF bar name
        LTF_Barname_Prev = LTF_Barname_Curr ;

        return;


     }



    /***********************************************************************************************/
    /***   FROM THIS POINT FORWARD, ONLY FIRST TICK OF LTF OPERATES   ***/
    /***********************************************************************************************/
    //-- Other ticks in the LTF bar are skipped





    //+---------------------------------------------------------------------------------------------+
    //| DETERMINE IF BIG PROFIT HAVE EVER BEEN ACHIEVED                                             |
    //+---------------------------------------------------------------------------------------------+
    //-- PREVENT NEW ENTRY IF BIG PROFIT HAS BEEN ACHIEVED
    //-- BIG PROFIT IS "LEG OF THE YEAR"; YOU WAIT UNTIL NEXT YEAR
    //-- OR YOU DISCOVER A STRONG WEEKLY "V" or "A" PATTERN OCCURS IN THE SAME YEAR
    
    //-- BIG PROFIT LOGIC
    //-- On CLOSED ORDERs:
      // LOGIC #1 - When orderProfitPips get larger than 0.75 * Percentile75 of target price
      // LOGIC #2 - When profit target is met = large profit.

    if( IsFirstTick_HTF )
    {
      Print("[OnTick]: *** TradeFlag_ClosedOnBigProfit: ", BoolToStr(TradeFlag_ClosedOnBigProfit) );
    }


    if( IsFirstTick_HTF && TradeFlag_ClosedOnBigProfit==false )
    {

          Print("[OnTick]:",
              " TradeFlag_ClosedOnBigProfit: " , BoolToStr(TradeFlag_ClosedOnBigProfit) );

          bool    selectedOrder   ;
          int     totalHistoryOrders = OrdersHistoryTotal();
          double  orderProfit       ;
          double  orderProfitPips   ;

          //-------------------------------------------------------
          // NOTE NOTE NOTE
          // Big Profit should be checked against P1 only !!
          // use the magic number for P1
          // if only the magic number works!
          // if not working, then, the system needs checking
          // all historical closed trade
          //-------------------------------------------------------

          for (int i=totalHistoryOrders-1 ; i>=0 ; i--)

          //-- "Back loop" because after order close,
          //--  this closed order removed from list of opened orders.
          //-- https://www.mql5.com/en/forum/44043

          {
            //-- Select the order
            selectedOrder = OrderSelect( i , SELECT_BY_POS , MODE_HISTORY );

            if (!selectedOrder)
              {

                string  _errMsg     ;
                int     _lastErrorNum  ;

                  _lastErrorNum = GetLastError() ;
                  _errMsg =
                        "Failed to select HISTORY order. Error: " + _lastErrorNum  +
                        " Desc: " + GetErrorDescription( _lastErrorNum )
                    ;
                Print( _errMsg );
                Alert( _errMsg );
                Sleep(3000);
              }

              /* Print("[OnTick]>[if(TradeFlag_ClosedOnBigProfit==false)] "
                  " Ticket: #",           IntegerToString( OrderTicket() )        ,
                  " OpenPrice(): " ,      DoubleToString( OrderOpenPrice() ,2 )   ,
                  " ClosedPrice(): " ,    DoubleToString( OrderClosePrice() ,2 )  ,
                  " OrderCloseTime():",   OrderCloseTime()
                  ); */

              if( selectedOrder == true
                  && (OrderType()==OP_BUY  || OrderType()==OP_SELL )
                  && OrderCloseTime() != 0 )
              {
                switch( OrderType() )
                {
                  case OP_BUY:
                    //-- TO DO orderProfit
                    orderProfit = OrderClosePrice() - OrderOpenPrice();
                  break;
                  case OP_SELL:
                    //-- TO DO orderProfit
                    orderProfit = OrderOpenPrice() - OrderClosePrice();
                  break;
                }
              }



              orderProfitPips  = orderProfit / ( Point * PointToPrice );

              bool _debugcheckactive_1 = false ;
              if (_debugcheckactive_1 )
                  Print("[OnTick]:"
                        " Ticket: #" , OrderTicket() ,
                        " OrderProfitPips: " , DoubleToStr( orderProfitPips ,0)  , "."
                        " This is CHECK on [for (int i=totalHistoryOrders-1 ; i>=0 ; i--)], i #" , i              
                        );
              
              
              // LOGIC #1 - When orderProfitPips get larger than 0.75 * Percentile75 of target price
              if ( orderProfitPips >= 0.75 * SymbolBasedTargetPrice75Pct( Symbol() ) )
              //-- TO DO
              //-- Need symbol-based function that return high profit for closed trade
              //-- 1500 is approximate for USDJPY.
              //
              {
                TradeFlag_ClosedOnBigProfit = true ;
                break;
              }
              
              // NOTE THE  LOGIC #2 - When profit target is met = large profit 
              // is for STRATEGY_MEDIUMTREND_WEEKLY_LARGE_RANGE
              // See "2. MONITOR TARGET" for Implementation
          }

    }





    // First tick alert

    if( IsFirstTick_HTF )
      {
        //Alert("First tick >>>> HTF") ;
      }
    if( IsFirstTick_MTF )
      {
        //Alert("First tick >>>> MTF") ;
      }
    if(IsFirstTick_LTF)
      {
        //Alert("First tick > LTF");
      }



    //+---------------------------------------------------------------------------------------------+
    //| TTF INDICATORS                                                                              |
    //+---------------------------------------------------------------------------------------------+

    static double macd_TTF_exit_hist_1  ;
    static double macd_TTF_exit_hist_X  ;
    if( IsFirstTick_TTF )
    {

      macd_TTF_exit_hist_1 = iCustom( NULL , PERIOD_TTF , "MACDH_OnCalc" ,
           18 , 39 , 18 ,
              2 , 1 ) ;
              // Buffer = 2 / index = 1

      macd_TTF_exit_hist_X = iCustom( NULL , PERIOD_TTF , "MACDH_OnCalc" ,
           18 , 39 , 18 ,
              2 , 2 ) ;
      // Buffer = 2 / index = 2



      //*****************//
      //*** DEBUGGING ***//
      //*****************//
      Print(
            "[OnTick]: *** WEEKLY BAR ***"
          + " Date: " + TimeToStr(Time[0] , TIME_DATE|TIME_MINUTES )
          + " " + DayOfWeekString( DayOfWeek() )
          + " MACDH WEEKLY [1]: " + DoubleToString( macd_TTF_exit_hist_1 , 4)
          + " MACDH WEEKLY [2]: " + DoubleToString( macd_TTF_exit_hist_X , 4)
                    );


    }





    //+---------------------------------------------------------------------------------------------+
    //| HTF INDICATORS                                                                              |
    //+---------------------------------------------------------------------------------------------+

    static double sma_HTF_drift_1       ;
    static double sma_HTF_drift_X       ;

    static double rsi3_HTF_1            ;
    static double rsi3_HTF_2            ;

    static bool   rsi3_HTF_cock_UP      ;
    static bool   rsi3_HTF_tick_UP      ;
    static bool   rsi3_HTF_cock_DOWN    ;
    static bool   rsi3_HTF_tick_DOWN    ;

    static double macd_HTF_entry_hist_1 ;
    static double macd_HTF_entry_hist_X ;

    static double macd_HTF_exit_hist_1  ;
    static double macd_HTF_exit_hist_X  ;

    static double highestHigh_HTF_3bars ;
    static double lowestLow_HTF_3bars   ;


    // you have to make it static variable to keep
    // the values between tick call

    if( IsFirstTick_HTF )
    {

      // SMA DRIFT
      // ----------------------

      sma_HTF_drift_1 = iMA(NULL , PERIOD_HTF , 5 , 0 , MODE_SMA , PRICE_MEDIAN , 1 );
      sma_HTF_drift_X = iMA(NULL , PERIOD_HTF , 5 , 0 , MODE_SMA , PRICE_MEDIAN , 3 );

      // RSI 3 HTF
      // ----------------------

      rsi3_HTF_1    = iRSI(NULL , PERIOD_HTF , 3 , PRICE_CLOSE , 1) ;
      rsi3_HTF_2    = iRSI(NULL , PERIOD_HTF , 3 , PRICE_CLOSE , 2) ;


      // RSI 3 HTF - COCKED UP
      // or COCKED DOWN
      // ----------------------

      if( rsi3_HTF_1 > 50.001 && rsi3_HTF_2 <= 50.000 )
      {
        rsi3_HTF_cock_UP    = true  ;
        rsi3_HTF_cock_DOWN  = false ;
      }

      if( rsi3_HTF_1 < 49.999 && rsi3_HTF_2 >= 50.000 )
      {
        rsi3_HTF_cock_UP    = false  ;
        rsi3_HTF_cock_DOWN  = true ;
      }

      if( rsi3_HTF_1 > rsi3_HTF_2 )
      {
        rsi3_HTF_tick_UP    = true  ;
        rsi3_HTF_tick_DOWN  = false ;
      }
      if( rsi3_HTF_1 < rsi3_HTF_2 )
      {
        rsi3_HTF_tick_UP    = false ;
        rsi3_HTF_tick_DOWN  = true  ;
      }



      // MACD ENTRY
      // ----------------------

      // MACDH uses PRICE_MEDIAN, not PRICE_CLOSE to gauge drift

      macd_HTF_entry_hist_1 = iCustom( NULL , PERIOD_HTF , "MACDH_OnCalc" ,
            12 , 26 , 9 ,
              2 , 1 ) ;
              // Buffer = 2 / index = 1

      macd_HTF_entry_hist_X = iCustom( NULL , PERIOD_HTF , "MACDH_OnCalc" ,
           12 , 26 , 9 ,
              2 , 2 ) ;
             // Buffer = 2 / index = 2


      // MACD EXIT
      // ----------------------

      macd_HTF_exit_hist_1 = iCustom( NULL , PERIOD_HTF , "MACDH_OnCalc" ,
           18 , 39 , 18 ,
              2 , 1 ) ;
              // Buffer = 2 / index = 1

      macd_HTF_exit_hist_X = iCustom( NULL , PERIOD_HTF , "MACDH_OnCalc" ,
           18 , 39 , 18 ,
              2 , 2 ) ;
              // Buffer = 2 / index = 2




      // PRICE CHANNEL
      // HIGHEST HIGH
      // ----------------------
      // int val_index_highest = iHighest( NULL , PERIOD_HTF , MODE_HIGH , 3 , 1 ) ;
      // highestHigh_HTF_3bars = High[ val_index_highest ] ;

      highestHigh_HTF_3bars = iCustom( NULL , PERIOD_HTF , "PChannel" , 3 , 
            0 , 1  );
            // Buffer = 0 / index = 1
      //
      // LOWEST LOW
      // ----------------------
      // int val_index_lowest  = iLowest( NULL , PERIOD_HTF , MODE_LOW , 3 , 1  );
      // lowestLow_HTF_3bars   = Low[ val_index_lowest ];
      
      lowestLow_HTF_3bars = iCustom(  NULL , PERIOD_HTF , "PChannel" , 3 , 
            1 , 1);
            // Buffer = 1 / index = 1


    }   // End of if( IsFirstTick_HTF )





    //+---------------------------------------------------------------------------------------------+
    //| MTF INDICATORS                                                                               |
    //+---------------------------------------------------------------------------------------------+


    static double rsi_MTF_slow_1 ;
    static double rsi_MTF_slow_X ;

    static double rsi_MTF_fast_1 ;
    static double rsi_MTF_fast_2 ;
    static double rsi_MTF_fast_3 ;
    static double rsi_MTF_fast_4 ;
    static double rsi_MTF_fast_X ;

    // you have to make it static variable to keep
    // the values between tick call


    if( IsFirstTick_MTF )
    {

      rsi_MTF_slow_1 = iRSI(NULL , PERIOD_MTF , 9 , PRICE_CLOSE , 1 );
      rsi_MTF_slow_X = iRSI(NULL , PERIOD_MTF , 9 , PRICE_CLOSE , 2 );

      rsi_MTF_fast_1 = iRSI(NULL , PERIOD_MTF , 4 , PRICE_CLOSE , 1 );  // Originally 6, not 4
      rsi_MTF_fast_X = iRSI(NULL , PERIOD_MTF , 4 , PRICE_CLOSE , 2 );  // Originally 6, not 4
      rsi_MTF_fast_2 = iRSI(NULL , PERIOD_MTF , 4 , PRICE_CLOSE , 2 );  // Originally 6, not 4
      rsi_MTF_fast_3 = iRSI(NULL , PERIOD_MTF , 4 , PRICE_CLOSE , 3 );  // Originally 6, not 4
      rsi_MTF_fast_4 = iRSI(NULL , PERIOD_MTF , 4 , PRICE_CLOSE , 4 );  // Originally 6, not 4


      // Print the tick count at hour 5 and on the fourth day
      if( Hour() == 5 && Day() % 4 == 0 )
       {
         Print( "[OnTick]:",
                " ***>> Ticks per hour: ******>> " , TickCountPerHour );
       }


      TickCountPerHour = 0 ;

    }





    //+---------------------------------------------------------------------------------------------+
    //| LTF INDICATORS                                                                              |
    //+---------------------------------------------------------------------------------------------+

    double bb_LTF_channel1_upper_2 ;
    double bb_LTF_channel2_lower_2 ;

    double bb_LTF_channel1_upper_1 ;
    double bb_LTF_channel2_lower_1 ;

    double lrco_LTF_1fast_1  ;
    double lrco_LTF_1fast_2  ;
    double lrco_LTF_2slow_1  ;
    double lrco_LTF_2slow_2  ;

    static double trailingstop_BUY   = -999.0;
    static double trailingstop_SELL  = 999.0;

    double atr_LTF_36bar_1   ;




    bb_LTF_channel1_upper_2 = iBands(NULL , PERIOD_M5 , 30 , 0.9 , 0 , PRICE_CLOSE , MODE_UPPER , 2 ) ;
    bb_LTF_channel2_lower_2 = iBands(NULL , PERIOD_M5 , 30 , 0.9 , 0 , PRICE_CLOSE , MODE_LOWER , 2 ) ;
    bb_LTF_channel1_upper_1 = iBands(NULL , PERIOD_M5 , 30 , 0.9 , 0 , PRICE_CLOSE , MODE_UPPER , 1 ) ;
    bb_LTF_channel2_lower_1 = iBands(NULL , PERIOD_M5 , 30 , 0.9 , 0 , PRICE_CLOSE , MODE_LOWER , 1 ) ;

    lrco_LTF_1fast_1 = iCustom( NULL , PERIOD_LTF , "LR_MA_OnCalc" ,
               10 , PRICE_TYPICAL , 0 ,
                  0 , 1 ) ;
                  // Buffer = 0 / index = 1
    lrco_LTF_1fast_2 = iCustom( NULL , PERIOD_LTF , "LR_MA_OnCalc" ,
               10 , PRICE_TYPICAL , 0 ,
                  0 , 2 ) ;
                  // Buffer = 0 / index = 2

    lrco_LTF_2slow_1 = iCustom( NULL , PERIOD_LTF , "LR_MA_OnCalc" ,
               30 , PRICE_TYPICAL , 0 ,
                  0 , 1 ) ;
                  // Buffer = 0 / index = 1

    lrco_LTF_2slow_2 = iCustom( NULL , PERIOD_LTF , "LR_MA_OnCalc" ,
               30 , PRICE_TYPICAL , 0 ,
                  0 , 2 ) ;
                  // Buffer = 0 / index = 2

    atr_LTF_36bar_1 = iATR( NULL , PERIOD_LTF , 3*12 , 0 ) ;












    /*-----------------------------------------------------------------------------------*/
    /****** DEBUGGING SECTION ******/
    /*-----------------------------------------------------------------------------------*/
    //-- Reading indicator values

    if( IsFirstTick_HTF )
      {

        // Print(
            // "SMA(5) = "         , DoubleToString( sma_HTF_drift_1 , 4)         , " / " ,
            // "MACDH(12,26,9)[1]: "   , DoubleToString( macd_HTF_entry_hist_1 , 5)  , " / " ,
            // "MACDH(18,36,18)[1]: "  , DoubleToString( macd_HTF_exit_hist_1 , 5)  , " / " ,
            // "MACDH(12,26,9)[2]: "   , DoubleToString( macd_HTF_entry_hist_X , 5)  , " / " ,
            // "MACDH(18,36,18)[2]: "  , DoubleToString( macd_HTF_exit_hist_X , 5)
            // );


        // VALUES PASSED QA !

        /*
    2016.07.01 00:05  EURUSD SMA(5) = 1.1087 / MACDH(12,26,9): -0.00197 / MACDH(18,36,18): -0.00235
    2016.07.04 00:00  EURUSD SMA(5) = 1.1077 / MACDH(12,26,9): -0.00156 / MACDH(18,36,18): -0.00225
    2016.07.05 00:00  EURUSD SMA(5) = 1.1098 / MACDH(12,26,9): -0.00109 / MACDH(18,36,18): -0.00203
    2016.07.06 00:00  EURUSD SMA(5) = 1.1110 / MACDH(12,26,9): -0.00121 / MACDH(18,36,18): -0.00221
    2016.07.07 00:00  EURUSD SMA(5) = 1.1106 / MACDH(12,26,9): -0.00104 / MACDH(18,36,18): -0.00216
        */

      }


    if( IsFirstTick_MTF )
      {
        //Print (
        //     "RSI(6): " , DoubleToStr(rsi_MTF_fast_1 , 4) , " / " ,
        //     "RSI(9): " , DoubleToStr(rsi_MTF_slow_1 , 4)
        //     );
        // MOST VALUES MATCHES WITH THAT OF TERMINAL. FEW VALUES DO NOT MATCH.
        // I STILL PASS IT
      }



    if( IsFirstTick_LTF )
      {

        // Print(
          // "BB Upper: "  , DoubleToStr(bb_LTF_channel1_upper_2, 6 ) , " / " ,
          // "BB Lower: "  , DoubleToStr(bb_LTF_channel2_lower_2, 6) , " / " ,
          // "LR(10): "    , DoubleToStr(lrco_LTF_1fast_1 , 6) , " / " ,
          // "LR(30): "    , DoubleToStr(lrco_LTF_2slow_1 , 6)
        // );

        // // VALUES PASSED QA !
      }




    /***********************************************************************************************/
    /***    BREAKEVEN STOP MANAGEMENT - BUYING + SELLING  ***/
    /***********************************************************************************************/

    //-- On P1: when P2 is in, P1 is to breakeven
    //-- On P2 and P3: When profit of P2 (and P3) greater than 100 pips, is to break even
    //-- This logic bit operates on LTF (M5)



    //-- Structure -- P1, P2, P3, ... Pn are defined by Magic Number
    //-- Going through P1, P2, P3, ... Pn use index number 1, 2, 3, ... n


    if( BreakEvenStop_Apply == true )
    {


      int     magic_number    ;
      int     magic_number_2  ;
      int     ticket          ;
      int     ticket_2        ;
      bool    result_modified ;
      int     _errNumber      ;

      double  newStopPrice    ;


      for (int iPos=1 ; iPos <= MaxPositions ; iPos++ )
      {

        if( iPos== 1 )
        {

          if( Breakeven_iPos_Applied[iPos] == false )
          {
            //-- Check if P1 exists
            magic_number = MagicNumberTable( Symbol() , iPos );
            if( FindThenSelectOpenOrder( magic_number , ticket ) == true )
            {


              //-- Add  for P1
              //-- DEBUG
              //-- Print
              //-- ticket # , magic number # , position #, entry price, lot size
              //-- to match with details of entry written on the chart
              // DO THE SAME WITH SELLING



              //-- Now P1 exists
              //-- Check if P2 exists
              magic_number_2 = MagicNumberTable( Symbol() , (iPos+1) );
              if( FindThenSelectOpenOrder( magic_number_2 , ticket_2 ) )
              {

                datetime  OrderOpenTime_P2  = OrderOpenTime()   ;
                datetime  OrderCloseTime_P2 = OrderCloseTime()  ;
                bool      P2_in_breakeven   = Breakeven_iPos_Applied[ 2 ] ;

                //-- Now P2 exists
                //-- This portion is executed in the next tick after P2 entered,
                //-- NOT in the same tick of P2 entering

                //-- Select P1 again, P1 must be modified into breakeven



                  //-- Add for P2
                  //-- DEBUG
                  //-- Print
                  //-- ticket # , magic number # , position #, entry price, lot size
                  //-- to match with details of entry written on the chart



                magic_number = MagicNumberTable( Symbol() , iPos );
                if( FindThenSelectOpenOrder( magic_number , ticket ) == true )
                {

                  //-- Add  for P1
                  //-- DEBUG
                  //-- Print
                  //-- ticket # , magic number # , position #, entry price, lot size
                  //-- to match with details of entry written on the chart

                  // THEN WE CAN COMPARE CONSISTENCY P1 / P2

                  if( P2_in_breakeven )
                  {
                      if( HiddenStopLossTarget == true )
                      {

                        result_modified = true ;

                        newStopPrice = ( OrderType()==OP_BUY) ?
                                OrderOpenPrice() + 0.0 * (Point * PointToPrice ) :
                                OrderOpenPrice() - 0.0 * (Point * PointToPrice ) ;
                        //-- Slippage handler

                        PositionTracker[ iPos ].SL = newStopPrice;

                      } // End of if( HiddenStopLossTarget == true )
                      else
                      {

                        newStopPrice = ( OrderType()==OP_BUY) ?
                                OrderOpenPrice() + 0.0 * (Point * PointToPrice ) :
                                OrderOpenPrice() - 0.0 * (Point * PointToPrice ) ;
                        //-- Slippage handler

                          result_modified = OrderModify(
                                            ticket ,
                                            OrderOpenPrice()    ,
                                            newStopPrice    ,   //-- This is new stop loss price
                                            OrderTakeProfit()   ,
                                            0                   ,
                                            clrYellow               //-- mark with yellow arrow
                                            );
                      } // End of ELSE on if( HiddenStopLossTarget == true )


                      if ( !result_modified )
                      {
                          _errNumber = GetLastError() ;

                          Print("[OnTick]:" ,
                                " >>> >>> >>> Error Modifying P1 to breakeven!" ,
                                " Error Number: "      , IntegerToString( _errNumber ) ,
                                " Error Description: " , GetErrorDescription( _errNumber )
                                );

                      } // End of if ( !result_modified )
                      else
                      {

                        Breakeven_iPos_Applied[iPos] = true;

                          Print("");
                          Print("[OnTick]:" ,
                                " *** *** P1 is now at breakeven Stop!" ,
                                " Ticket #" , ticket ,
                                " Magic Number: " , magic_number ,
                                " Breakeven_P1_Applied: " , BoolToStr( Breakeven_iPos_Applied[iPos] )
                              );
                          Print("[OnTick] > DEBUGGING:" ,
                                " Position P2 identified with ticket #" , IntegerToString( ticket_2 ),
                                " magic number P2: " , IntegerToString( magic_number_2 ),
                                " OrderOpenTime() P2: " , TimeToString( OrderOpenTime_P2 , TIME_DATE|TIME_MINUTES ) ,
                                " OrderCloseTime() P2: " , TimeToString( OrderCloseTime_P2 , TIME_DATE|TIME_MINUTES )
                              );
                          Print("");

                      } // End of else - if ( !result_modified )


                  } // End of "if( P2_in_breakeven )"


                }   // End of "if( FindThenSelectOpenOrder( magic_number , ticket ) == true)"
                else
                {
                    //-- Error - no selection P1
                    _errNumber = GetLastError();
                    Print("[OnTick]:" ,
                          " >>> >>> >>> NO SELECTION Error Modifying P1 to breakeven!" ,
                          " Error Number: "      , IntegerToString( _errNumber ) ,
                          " Error Description: " , GetErrorDescription( _errNumber )
                          );

                } // End of if( FindThenSelectOpenOrder( magic_number , ticket ) == true ) on P1
              } // End of if( FindThenSelectOpenOrder( magic_number_2 , ticket_2 ) ) on P2

            } // End of if( FindThenSelectOpenOrder( magic_number , ticket ) == true ) on P1
          }  // End of if( Breakeven_iPos_Applied[iPos] == false )

        }   // if(iPos == 1 )
        else // if(iPos == 1) else
        {

          //-- now work on P2, P3, Pn
          //-- they will be set on breakeven when profit is 250 pips

          if( Breakeven_iPos_Applied[iPos] == false )
          {

            //-- select the order
            //-- once selected, check the profit
            //-- if profit > 100 pips, lock to break even

            magic_number = MagicNumberTable( Symbol() , iPos );
            if( FindThenSelectOpenOrder( magic_number , ticket ) )
            {

              // the order exists
              // check its profit


              double profit_in_pips ;

              if( OrderType() == OP_BUY )
              //-- This is for BUYING
              {
                  profit_in_pips =
                    ( Close[1] - OrderOpenPrice() )  // Close[1] of M5
                    /
                    ( Point * PointToPrice ) ;
              }
              else
              // -- This is for SELLING
              {
                  profit_in_pips =
                    ( OrderOpenPrice() - Close[1] )  // Close[1] of M5
                    /
                    ( Point * PointToPrice ) ;
              }

              if( profit_in_pips > 100.0 )
              {



                  if( HiddenStopLossTarget )
                  {
                    result_modified = true ;

                    newStopPrice = ( OrderType()==OP_BUY) ?
                            OrderOpenPrice() + 0.0 * (Point * PointToPrice ) :
                            OrderOpenPrice() - 0.0 * (Point * PointToPrice ) ;
                    //-- Slippage handler

                    PositionTracker[iPos].SL = newStopPrice;
                  }
                  else
                  {

                    newStopPrice = ( OrderType()==OP_BUY) ?
                            OrderOpenPrice() + 0.0 * (Point * PointToPrice ) :
                            OrderOpenPrice() - 0.0 * (Point * PointToPrice ) ;
                    //-- Slippage handler

                      result_modified = OrderModify(
                                        ticket            ,
                                        OrderOpenPrice()  ,
                                        newStopPrice  ,   //-- this is new stop loss price
                                        OrderTakeProfit() ,
                                        0                 ,
                                        clrYellow             //-- mark with yellow arrow
                                        );
                  } // End of ELSE on if( HiddenStopLossTarget )



                  if( !result_modified )
                  {
                      Print("[OnTick]: " ,
                            " >>> >>> >>> Error Modifying P[",iPos,"] to breakeven!" ,
                            " Error Number: "      , IntegerToString( _errNumber ) ,
                            " Error Description: " , GetErrorDescription( _errNumber )
                            );
                  } // before ELSE of if( !result_modified )
                  else
                  {

                    Breakeven_iPos_Applied[iPos] = true;

                    Print("") ;
                    Print("[OnTick]:" ,
                          " *** *** P[", iPos , "] is now at breakeven Stop!" ,
                          " Breakeven_iPos_Applied[",iPos,"]: " , BoolToStr( Breakeven_iPos_Applied[iPos] ) ,
                          " ProfitPips: " , DoubleToString( profit_in_pips , 0 ) , " pips."
                          );
                    Print("") ;

                  } // End of ELSE if( !result_modified )


              }   // End of if( profit_in_pips > 100.0 )


            }   // before ELSE of if( FindThenSelectOpenOrder( magic_number , ticket ) )
            else
            {
              // no more open position
              // exit loop
              break;
            }   // End of ELSE if( FindThenSelectOpenOrder( magic_number , ticket ) )


          } // End of if( Breakeven_iPos_Applied[iPos] == false )

        } // End of ELSE of if(iPos == 1)


      } // End of for (int iPos=1 ; iPos <= MaxPositions ; iPos++ )


    } // End of if( BreakEvenStop_Apply == true )







    /***********************************************************************************************/
    /***    PROFIT LOCKING 250 PIPS - BUYING + SELLING  ***/
    /***********************************************************************************************/

    if( ProfitLock250pips_Apply )
    {

      int   magic_number    ;
      int   ticket          ;
      int   result_modified ;
      int   _errNumber      ;

      for (int iPos=1 ; iPos <= MaxPositions ; iPos++ )
      {

        if( iPos == 1 )
        //-- On P1
        {

          if( ProfitLock250Pips_iPos_Applied[iPos] == false )
          {
            //-- Check if P1 exists
            magic_number = MagicNumberTable( Symbol() , iPos );
            if( FindThenSelectOpenOrder( magic_number , ticket ) == true )
            {

              double  profit_in_pips  ;
              int     _orderType      = OrderType() ;
              // Get the value of order type once, and use the value multiple times

              if( _orderType == OP_BUY )
              //-- BUYING section
              {
                profit_in_pips =
                    ( Close[1] - OrderOpenPrice() )
                    /
                    ( Point * PointToPrice );

              }   // End of "if( OrderType() == OP_BUY )"
              else if( _orderType == OP_SELL )
              //-- SELLING section
              {
                profit_in_pips =
                    ( OrderOpenPrice() - Close[1] )
                    /
                    ( Point * PointToPrice );

              }   // End of SELLING, i.e., End of ELSE on "if( OrderType() == OP_BUY )"
              else
              {
                Print("[OnTick]" ,
                      " *** WARNING: OrderType() is NOT OP_BUY NOR OP_SELL !!!"
                    );
              } // End of ELSE on "else if( _orderType == OP_SELL )"


              if (profit_in_pips >= 1200.0 )
              {

                //-- This is new stoploss price
                if( _orderType==OP_BUY )
                {
                  ProfitLock250pips_NewStopPrice = OrderOpenPrice() + 250.0 * (Point * PointToPrice) ;
                } // End of if( OrderType()==OP_BUY )
                else if( _orderType == OP_SELL )
                {
                  ProfitLock250pips_NewStopPrice = OrderOpenPrice() - 250.0 * (Point * PointToPrice) ;
                } // End of SELLING
                else
                {
                  Print("[OnTick]" ,
                        " *** WARNING: OrderType() is NOT OP_BUY NOR OP_SELL !!!"
                      );
                } // End of ELSE on "else if( _orderType == OP_SELL )"



                if( HiddenStopLossTarget )
                {
                    result_modified = true ;
                    PositionTracker[iPos].SL = ProfitLock250pips_NewStopPrice ;
                }
                else
                {
                    result_modified = OrderModify(
                                ticket ,
                                OrderOpenPrice() ,
                                ProfitLock250pips_NewStopPrice ,
                                OrderTakeProfit() ,
                                0 ,
                                clrYellow     //-- mark with yellow arrow
                                );
                }


                if( !result_modified )
                {
                  _errNumber = GetLastError();
                  Print("[OnTick]: " ,
                        " >>> >>> >>> Error Modifying P", iPos ," to lock profit at 250 pips!" ,
                        " Error Number: "      , IntegerToString( _errNumber ) ,
                        " Error Description: " , GetErrorDescription( _errNumber )
                        );
                }
                else
                {

                  ProfitLock250Pips_iPos_Applied[iPos] = true ;

                  Print("") ;
                  Print("**** PROFIT LOCKING ****") ;
                  Print("[OnTick]:" ,
                        " *** *** P", iPos ," is now at 250 pips profit lock !" ,
                        " ProfitLock250pips_P", iPos ,"_Applied: " , BoolToStr( ProfitLock250Pips_iPos_Applied[iPos] ) ,
                        " ProfitPips: " , DoubleToString( profit_in_pips , 0 ) , " pips."
                        );
                  Print("**** PROFIT LOCKING ****") ;
                  Print("") ;
                }   // End of   if( !result_modified )


              } // End of if (profit_in_pips >= 1200.0 )

            } // End of if( FindThenSelectOpenOrder( magic_number , ticket ) == true )

          }   // End of if( ProfitLock250Pips_iPos_Applied[iPos] == false )

        }   // End of if( iPos == 1 )
        else
        //-- On P2, P3, and so on
        {

          if( ProfitLock250Pips_iPos_Applied[iPos] == false && ProfitLock250Pips_iPos_Applied[ 1 ] == true )
          //-- applicable if The First Position already locking profit at 250 pips
          //-- raise the stop to the same level with 250 pips level of the First Position's
          {

            magic_number = MagicNumberTable( Symbol() , iPos );
            if( FindThenSelectOpenOrder(magic_number , ticket) == true )
            {
              double  profit_in_pips ;
              int     _orderType      = OrderType();
              double  _orderOpenPrice = OrderOpenPrice();
              // Get the value once, use everywhere under parent bracket

              if( _orderType==OP_BUY )
              {
                profit_in_pips =
                        ( Close[1] - _orderOpenPrice )  //-- Close[1] is of M5
                        /
                        ( Point * PointToPrice ) ;
              }
              else if ( _orderType==OP_SELL )
              {
                profit_in_pips =
                        ( _orderOpenPrice - Close[1] )  //-- Close[1] is of M5
                        /
                        ( Point * PointToPrice ) ;
              }
              else
              {
                Print("[OnTick]" ,
                      " *** WARNING: OrderType() is NOT OP_BUY NOR OP_SELL !!!"
                      );
              }


              if(
                      ( _orderOpenPrice < ProfitLock250pips_NewStopPrice && _orderType==OP_BUY  )
                  ||  ( _orderOpenPrice > ProfitLock250pips_NewStopPrice && _orderType==OP_SELL )
                )
              {

                if( HiddenStopLossTarget )
                {
                  result_modified = true ;
                  PositionTracker[iPos].SL = ProfitLock250pips_NewStopPrice ;
                }
                else
                {

                  result_modified = OrderModify(
                              ticket ,
                              _orderOpenPrice ,
                              ProfitLock250pips_NewStopPrice ,
                              OrderTakeProfit() ,
                              0 ,
                              clrYellow     //-- mark with yellow arrow
                              );

                } // End of if( HiddenStopLossTarget )


                if( !result_modified )
                {
                  _errNumber = GetLastError();
                  Print("[OnTick]: " ,
                        " >>> >>> >>> Error Modifying P",iPos," to lock profit at the same level of P1!" ,
                        " Error Number: "      , IntegerToString( _errNumber ) ,
                        " Error Description: " , GetErrorDescription( _errNumber )
                        );
                }
                else
                {
                  ProfitLock250Pips_iPos_Applied[iPos] = true ;

                  Print("") ;
                  Print("**** PROFIT LOCKING ****") ;
                  Print("[OnTick]:" ,
                        " *** *** P", iPos ," is now at P1's 250 pips profit lock !" ,
                        " ProfitLock250pips_P" , iPos , "_Applied: " , BoolToStr( ProfitLock250Pips_iPos_Applied[iPos] ) ,
                        " ProfitPips: " , DoubleToString( profit_in_pips , 0 ) , " pips."
                        );
                  Print("**** PROFIT LOCKING ****") ;
                  Print("") ;
                }

              } //-- End of if( OrderOpenPrice() < ProfitLock250pips_NewStopPrice )

            } // End of if( FindThenSelectOpenOrder(magic_number , ticket) == true )


          } // End of if( ProfitLock250Pips_iPos_Applied[iPos]==false && ProfitLock250Pips_iPos_Applied[1]==true )

        }   // End of ELSE on if( iPos == 1 )

      }   // End of for (int iPos-1 ; iPos <= MaxPositions ; iPos++ )



    }   // End of if( ProfitLock250pips_Apply )







    /*/////////////////////////////////////////////////////////////////////////////////////////////*/
    /***********************************************************************************************/
    /***   EXIT MANAGEMENT   ***/
    /***********************************************************************************************/
    /*/////////////////////////////////////////////////////////////////////////////////////////////*/

    


    //+---------------------------------------------------------------------------------------------+
    //| EXIT BY DELIBERATE EXCLUSION DAY / ZONE                                                     |
    //+---------------------------------------------------------------------------------------------+


    if( IsFirstTick_LTF == true )
    {



        // EXIT FROM EXCLUSION ZONE

        EXIT_EXCLZONE(
                   closedByTechnicalAnalysis ,
                   // RInitPips ,
                   // RMult_Final,
                   comment_exit
                   );


    }  // end of if( IsFirstTick_LTF == true )





    //+---------------------------------------------------------------------------------------------+
    //| EXIT BUY + EXIT SELL STRATEGY_LONGTREND_LEG_OF_THE_YEAR TECHNICAL RULE                      |
    //+---------------------------------------------------------------------------------------------+


    /*-----------------------------------------------------------------------------------*/
    /****** TECHNICAL DEFINITION FOR EXIT ******/
    /*-----------------------------------------------------------------------------------*/

    // CODES NEEDS TO BE CLEAN AS POSSIBLE
    // COMMENTARIES NEEDS CONCISE, SUCCINCT 


    bool exitBuy  = false ;
    bool exitSell = false ;



    /*++ 	STRATEGY_LONGTREND_LEG_OF_THE_YEAR 	++*/
    /*-----------------------------------------------------------------------------------*/


    if( IsFirstTick_TTF && Strategy_Trend == STRATEGY_LONGTREND_LEG_OF_THE_YEAR )
    {


      //-- Exit rule that I am comfortable with:
      //-- after 1,750 pips profit on P1
      //-- use macd_TTF_exit_hist downtick as exit rule
      //-- This allows profit to work out to USDJPY 1700 pips more,
      //-- to allow profit grows,
      //-- to ignore short-term fluctuation, to ignore noises,
      //-- before letting the trend end itself.

      //-- Calculate Order Profit in Pips
      int     ticket = FindTicket( MagicNumberTable( Symbol() , 1  ) );
      bool    res             = OrderSelect( ticket , SELECT_BY_TICKET , MODE_TRADES );

      //-- Assign once, use everywhere in the current bracket
      int     _orderType      = OrderType() ;
      double  _orderOpenPrice = OrderOpenPrice() ;

      if( res == true
        && ( _orderType==OP_BUY || _orderType==OP_SELL )
        &&  OrderCloseTime() == 0 )
      {

        double  OrderP1ProfitPrice ;
        if(_orderType==OP_BUY)
        {
          OrderP1ProfitPrice = Close[1] - _orderOpenPrice ;
        }
        else if(_orderType==OP_SELL)
        {
          OrderP1ProfitPrice = _orderOpenPrice - Close[1] ;
        }
        else
        {
          Print("[OnTick]" ,
                " *** WARNING: OrderType() is NOT OP_BUY NOR OP_SELL !!!"
              );
        }


        double  OrderP1ProfitPips   = OrderP1ProfitPrice / (Point * PointToPrice);

        //-- Note, Close[1] is the last close of M5 - the lowest time frame,
        //-- that also happens as the close of W1, because this tick is happening
        //-- as the first tick of W1

        // Flag the position at high profit
        if( OrderP1ProfitPips >= ThresholdProfitPips_HighThresh) 
            TradeFlag_ProfitThresholdPassed = true ;
        //-- The flag is reset on entering a new position
        //-- DONE
        //-- Need symbol-based function for this function


        if( _orderType==OP_BUY )
        {
          exitBuy = (
                    (macd_TTF_exit_hist_1 < macd_TTF_exit_hist_X)
                &&  TradeFlag_ProfitThresholdPassed
                    // Profit threshold for the FX has been passed
                );
        }
        else if(_orderType==OP_SELL)
        {
          exitSell = (
                    (macd_TTF_exit_hist_1 > macd_TTF_exit_hist_X)
                &&  TradeFlag_ProfitThresholdPassed
                    // Profit threshold for the FX has been passed
                );
        }
        else
        {
          Print("[OnTick]" ,
                " *** WARNING: OrderType() is NOT OP_BUY NOR OP_SELL !!!"
              );
        }


        //*****************//
        //*** DEBUGGING ***//
        //*****************//
        Print(
                "[OnTick]: "
              , "*** WEEKLY BAR ***"
              , " Close[1]: "           , DoubleToString(Close[1] , 2)
              , " OrderOpenPrice: "     , DoubleToString(OrderOpenPrice() , 2  )
              , " Ticket P1: "          , IntegerToString(ticket)
              , " OrderP1ProfitPrice: " , DoubleToString(OrderP1ProfitPrice , 4)
              , " OrderP1ProfitPips: "  , DoubleToString(OrderP1ProfitPips , 1)
              , " MACDH W1 [1]: "       , DoubleToString(macd_TTF_exit_hist_1 , 4)
              , " MACDH W1 [2]: "       , DoubleToString(macd_TTF_exit_hist_X , 4)
              , " exitBuy: "            , BoolToStr( exitBuy )
            );
            
      }   // End of  if( res == true
          //              && ( _orderType==OP_BUY || _orderType==OP_SELL )
          //              &&  OrderCloseTime() == 0 )



      // exitBuy = (
                  // macd_TTF_exit_hist_1 < 0
              // &&  macd_TTF_exit_hist_X >= 0
                  // );    //-- A cross down from positive_sign to negative_sign



    }   // End of if( IsFirstTick_TTF && Strategy_Trend == STRATEGY_LONGTREND_LEG_OF_THE_YEAR )



    // if( IsFirstTick_HTF == true )
    //{

        //-- In TM_LONG ; long-only trade, the exit buy signal exists
        //-- This section should contain techincal definition on technical exit signal
        //-- without considering any ticket !
        //-- The closing should be "CLOSE ALL OPEN POSITION"

        // exitBuy = (
                  // macd_HTF_exit_hist_1 < 0
              // &&  macd_HTF_exit_hist_X >= 0
                  // );    //-- A cross down from positive_sign to negative_sign

    //}


    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\
    * Notes:
    * --------------
    * On TRAILING STOP CALCULATION, refer to
    *   C:\Users\Hendy\AppData\Roaming\MetaQuotes\Terminal\50CA3DFB510CC5A8F28B48D1BF2A5702\..
    *   MQL4\Experts\MVTS_3_ATRTrailStop 1.04.mq4
    *
    * Tips:
    * --------------
    * Trailing stop can be on HTF, MTF, or LTF.
    * use IsFirstTick_HTF / IsFirstTick_MTF / IsFirstTick_LTF and ATR value relevant to its timeframe
    * and Low[1] or High[1] from the respective timeframe.
    * The Low[] or the High[] depends on timeframe of the *current chart*
    * To access Low[] or the High[] from different timeframe use iLow() and iHigh() function
    *
    \~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/




    /*-----------------------------------------------------------------------------------*/
    /****** EXECUTION - EXIT BUY - STRATEGY_LONGTREND_LEG_OF_THE_YEAR ******/
    /*-----------------------------------------------------------------------------------*/

    if( Strategy_Trend == STRATEGY_LONGTREND_LEG_OF_THE_YEAR )
      if( IsFirstTick_TTF && exitBuy && TradeMode == TM_LONG  )
      {

        //*****************//
        //*** DEBUGGING ***//
        //*****************//
          Print(

            "[OnTick] ======== EXIT BUY WEEKLY CALL ===== " ,
             "MACDH TTF(18,36,18)[1]: "  , DoubleToString( macd_TTF_exit_hist_1 , 5) , " / " ,
             "MACDH TTF(18,36,18)[2]: "  , DoubleToString( macd_TTF_exit_hist_X , 5)
            );


        //-- The closing should be "CLOSE ALL OPEN POSITION"
        //-- The logic below is still from older logic that close first position only
        //-- I want simpler logic to close **all open position**

        EXIT_ALL_POSITIONS(
            closedByTechnicalAnalysis   ,
            comment_exit
            );

        if( closedByTechnicalAnalysis==true )
        {

          TradeFlag_ClosedOnBigProfit = true;
          //-- Set flag for Closed on big profit = true
          //-- No more entries after this.

          Print( "" );
          Print( "[OnTick]: ****** ALL POSITIONS HAVE BEEN CLOSED IN HIGH PROFIT ***" );
          Print( "[OnTick]: ****** NO MORE TRADE ENTRY AFTER THIS ***" );
          Print( "" );
        }

      }





    /*-----------------------------------------------------------------------------------*/
    /****** EXECUTION - EXIT SELL - STRATEGY_LONGTREND_LEG_OF_THE_YEAR ******/
    /*-----------------------------------------------------------------------------------*/

    if( Strategy_Trend == STRATEGY_LONGTREND_LEG_OF_THE_YEAR )
      if( IsFirstTick_TTF &&  exitSell &&  TradeMode == TM_SHORT )
      {

        //*****************//
        //*** DEBUGGING ***//
        //*****************//
          Print(

            "[OnTick] ======== EXIT SELL WEEKLY CALL ===== " ,
             "MACDH TTF(18,36,18)[1]: "  , DoubleToString( macd_TTF_exit_hist_1 , 5) , " / " ,
             "MACDH TTF(18,36,18)[2]: "  , DoubleToString( macd_TTF_exit_hist_X , 5)
            );


        //-- The closing should be "CLOSE ALL OPEN POSITION"
        //-- The logic below is still from older logic that close first position only
        //-- I want simpler logic to close **all open position**

        EXIT_ALL_POSITIONS(
            closedByTechnicalAnalysis   ,
            comment_exit
            );

        if( closedByTechnicalAnalysis==true )
        {

          TradeFlag_ClosedOnBigProfit = true;
          //-- Set flag for Closed on big profit = true
          //-- No more entries after this.

          Print( "" );
          Print( "[OnTick]: ****** ALL POSITIONS HAVE BEEN CLOSED IN HIGH PROFIT ***" );
          Print( "[OnTick]: ****** NO MORE TRADE ENTRY AFTER THIS ***" );
          Print( "" );
        }

      }



    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\
    * Notes:
    * --------------
    * On TRAILING STOP CALCULATION, refer to
    *   C:\Users\Hendy\AppData\Roaming\MetaQuotes\Terminal\50CA3DFB510CC5A8F28B48D1BF2A5702\..
    *   MQL4\Experts\MVTS_3_ATRTrailStop 1.04.mq4
    *
    * Tips:
    * --------------
    * Trailing stop can be on HTF, MTF, or LTF.
    * use IsFirstTick_HTF / IsFirstTick_MTF / IsFirstTick_LTF and ATR value relevant to its timeframe
    * and Low[1] or High[1] from the respective timeframe.
    * The Low[] or the High[] depends on timeframe of the *current chart*
    * To access Low[] or the High[] from different timeframe use iLow() and iHigh() function
    *
    \~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


    

    //+---------------------------------------------------------------------------------------------+
    //| EXIT BUY + EXIT SELL STRATEGY_MEDIUMTREND_WEEKLY_LARGE_RANGE TECHNICAL RULE                 |
    //+---------------------------------------------------------------------------------------------+    
    
    
    
      // Rule to writing code
      // Plan the idea on paper
        // Details step by step of the idea on paper
        
      // Writing the code on the Notepad++ or IDE
        // Write up the step by step of idea from paper on IDE coding as commentary
        // Fills the steps by steps with proper constructions. Example
        // of a construct is empty if().. else {}, or for() {} . 
        // A construct provides SKELETON for detailed coding.
        
        // Fills the construct with detailed variable declarations, and operations.
      
      
      // This current codes is already in generalized form. Before having generalized form, 
      // I started writing the codes from simpler, where P1 to P6 entries are in a block each, 
      // hence long codes. Long codes gives me clarity, however, when changing rules on a block, 
      // all blocks needs updates. Although simpler in logic, however, it more complex in maintenance.
      
      // Generalized form, wraps entries from P1 to P6 into for(i=1 to 6) loop, 
      // making the code shorter. Shorter codes are easier to maintain, however, the logic is not 
      // immediately clear.
      
      

      
    /*++ 	STRATEGY_MEDIUMTREND_WEEKLY_LARGE_RANGE 	++*/
    /*-----------------------------------------------------------------------------------*/

    bool exitBuy_SMT    = false ;   // _SMT = Strategy Medium Trend
    bool exitSell_SMT   = false ;   // _SMT = Strategy Medium Trend

    if( IsFirstTick_LTF && Strategy_Trend == STRATEGY_MEDIUMTREND_WEEKLY_LARGE_RANGE )
    {
      
      // Profit pass 500 pips?
      
      // If yes, apply trailing stop
      
        // Lowest low of 3 bar, taken its highest value, hence never fall back.        
        // Draw trailing stop with "x-x" on M5        
        // SEE LINE 3468 to 3477 for highest high 3 bar and lowest low 3 bars
        
        

        //-- Exit rule that I am comfortable with:
        //-- after 500 pips profit on P1
        //-- Use trailing stop of HTF 3 BARS
        //-- This allows profit to grow toward profit target of medium trend, and prepare for fallback 
        //-- to lock sizable profit on medium trend
        
        //-- The logic works on M5, NOT, on Closing D1       


      //-- Calculate Order Profit in Pips on P1
      int     ticket = FindTicket( MagicNumberTable( Symbol() , 1  ) );   // The 1 is for Position 1
      bool    res             = OrderSelect( ticket , SELECT_BY_TICKET , MODE_TRADES );

      //-- Assign once, use everywhere in the current bracket
      int     _orderType      = OrderType() ;
      double  _orderOpenPrice = OrderOpenPrice() ;

      if( res == true
        && ( _orderType==OP_BUY || _orderType==OP_SELL )
        &&  OrderCloseTime() == 0 )
      {

        double  OrderP1ProfitPrice ;
        if(_orderType==OP_BUY)
        {
          OrderP1ProfitPrice = Close[1] - _orderOpenPrice ;
        }
        else if(_orderType==OP_SELL)
        {
          OrderP1ProfitPrice = _orderOpenPrice - Close[1] ;
        }
        else
        {
          Print("[OnTick] - STRATEGY_MEDIUMTREND_WEEKLY_LARGE_RANGE" ,
                " *** WARNING: OrderType() is NOT OP_BUY NOR OP_SELL !!!"
              );
        }


        double  OrderP1ProfitPips   = OrderP1ProfitPrice / (Point * PointToPrice);

        //-- Note, Close[1] is the last close of M5 - the lowest time frame,

        // Flag the position if P1 pass the ThresholdProfitPips_LowThresh 
        // (I started with 500 pips for this value in the OnInit )
        
        if( OrderP1ProfitPips >= ThresholdProfitPips_LowThresh ) 
            TradeFlag_ProfitThresholdPassed = true ;

        
        if( _orderType==OP_BUY )
        {
          exitBuy = (                    
                    ( Close[1] < lowestLow_HTF_3bars )
                &&  TradeFlag_ProfitThresholdPassed
                  );
          // TIPS: Good practice
          // That TradeFlag_ProfitThresholdPassed is included into the formula for logic, 
          // because TradeFlag_ProfitThresholdPassed is part of exit criteria.
        }
        else if(  _orderType==OP_SELL  )
        {
          exitSell = (
                      ( Close[1] > highestHigh_HTF_3bars )
                &&  TradeFlag_ProfitThresholdPassed
                );
          // TIPS: Good practice
          // That TradeFlag_ProfitThresholdPassed is included into the formula for logic, 
          // because TradeFlag_ProfitThresholdPassed is part of exit criteria.
          
        }
        else
            {
              Print("[OnTick] - EXIT FOR MEDIUM TREND" ,
                    " *** WARNING: OrderType() is NOT OP_BUY NOR OP_SELL !!!"
                  );
            }      
        



            //*****************//
            //*** DEBUGGING ***//
            //*****************//
            if ( TradeFlag_ProfitThresholdPassed )
            {
                Print(
                        "[OnTick]: "
                      , "*** MEDIUM TREND ***"
                      , " Close[1]: "           , DoubleToString(Close[1] , 2)
                      , " OrderOpenPrice: "     , DoubleToString(OrderOpenPrice() , 2  )
                      , " Ticket P1: "          , IntegerToString(ticket)
                      //, " OrderP1ProfitPrice: " , DoubleToString(OrderP1ProfitPrice , 4)
                      , " OrderP1ProfitPips: "  , DoubleToString(OrderP1ProfitPips , 1)
                      , " Lowest Low 3 bars: "  , DoubleToString(lowestLow_HTF_3bars , 4)
                      , " Highest High 3 bars: ", DoubleToString(highestHigh_HTF_3bars , 4)
                      , " exitBuy: "            , BoolToStr( exitBuy )
                      , " exitSell: "           , BoolToStr( exitSell )
                    );
            }
            
      }   // End of  if( res == true
          //              && ( _orderType==OP_BUY || _orderType==OP_SELL )
          //              &&  OrderCloseTime() == 0 )
      
      
    } // End of if( IsFirstTick_LTF && Strategy_Trend == STRATEGY_MEDIUMTREND_WEEKLY_LARGE_RANGE )




      
    /*-----------------------------------------------------------------------------------*/
    /****** EXECUTION - EXIT BUY - STRATEGY_MEDIUMTREND_WEEKLY_LARGE_RANGE ******/
    /*-----------------------------------------------------------------------------------*/

    if( Strategy_Trend == STRATEGY_MEDIUMTREND_WEEKLY_LARGE_RANGE )
      if( IsFirstTick_LTF && exitBuy && TradeMode == TM_LONG  )
      {

        //*****************//
        //*** DEBUGGING ***//
        //*****************//
          Print(

            "[OnTick] ======== EXIT BUY MEDIUM TREND ===== " 
             //,
             //"MACDH TTF(18,36,18)[1]: "  , DoubleToString( macd_TTF_exit_hist_1 , 5) , " / " ,
             //"MACDH TTF(18,36,18)[2]: "  , DoubleToString( macd_TTF_exit_hist_X , 5)
            );


        //-- The closing should be "CLOSE ALL OPEN POSITION"
        //-- The logic below is still from older logic that close first position only
        //-- I want simpler logic to close **all open position**

        EXIT_ALL_POSITIONS(
            closedByTechnicalAnalysis   ,
            comment_exit
            );

        if( closedByTechnicalAnalysis==true )
        {

          TradeFlag_ClosedOnBigProfit = true;
          //-- Set flag for Closed on big profit = true
          //-- No more entries after this.

          Print( "" );
          Print( "[OnTick]: MEDIUM TREND EXIT ****** ALL POSITIONS HAVE BEEN CLOSED IN HIGH PROFIT ***" );
          Print( "[OnTick]: MEDIUM TREND EXIT ****** NO MORE TRADE ENTRY AFTER THIS ***" );
          Print( "" );
        }

      }





    /*-----------------------------------------------------------------------------------*/
    /****** EXECUTION - EXIT SELL - STRATEGY_MEDIUMTREND_WEEKLY_LARGE_RANGE ******/
    /*-----------------------------------------------------------------------------------*/

    if( Strategy_Trend == STRATEGY_MEDIUMTREND_WEEKLY_LARGE_RANGE )
      if( IsFirstTick_LTF &&  exitSell &&  TradeMode == TM_SHORT )
      {

        //*****************//
        //*** DEBUGGING ***//
        //*****************//
          Print(

            "[OnTick] ======== EXIT SELL MEDIUM TREND ===== " 
            //,
            // "MACDH TTF(18,36,18)[1]: "  , DoubleToString( macd_TTF_exit_hist_1 , 5) , " / " ,
            // "MACDH TTF(18,36,18)[2]: "  , DoubleToString( macd_TTF_exit_hist_X , 5)
            );


        //-- The closing should be "CLOSE ALL OPEN POSITION"
        //-- The logic below is still from older logic that close first position only
        //-- I want simpler logic to close **all open position**

        EXIT_ALL_POSITIONS(
            closedByTechnicalAnalysis   ,
            comment_exit
            );

        if( closedByTechnicalAnalysis==true )
        {

          TradeFlag_ClosedOnBigProfit = true;
          //-- Set flag for Closed on big profit = true
          //-- No more entries after this.

          Print( "" );
          Print( "[OnTick]: MEDIUM TREND EXIT ****** ALL POSITIONS HAVE BEEN CLOSED IN HIGH PROFIT ***" );
          Print( "[OnTick]: MEDIUM TREND EXIT ****** NO MORE TRADE ENTRY AFTER THIS ***" );
          Print( "" );
        }

      }









    /*-----------------------------------------------------------------------------------*/
    /****** JOURNALING ON EXIT BY TECHNICAL DECISION ******/
    /*-----------------------------------------------------------------------------------*/
        //-- Reporting on trade closure by "Technical Decision"
        //-- "Technical Decision" is technical rules, either by indicator reading,
        //-- or, by deliberate Exclusion Zone

        // TRADING_JOURNAL_CLOSED_BYTECHNICAL( );


    /*-----------------------------------------------------------------------------------*/
    /****** JOURNALING ON EXIT BY STOP LOSS OR PROFIT TARGET ******/
    /*-----------------------------------------------------------------------------------*/
        // EXIT_BY_STOP_OR_TARGET( );





        
        


    /*/////////////////////////////////////////////////////////////////////////////////////////////*/
    /***********************************************************************************************/
    /***   ENTRY MANAGEMENT   ***/
    /***********************************************************************************************/
    /*/////////////////////////////////////////////////////////////////////////////////////////////*/




                //*****************//
                //*** DEBUGGING ***//
                //*****************//

                //-- Adjust digit number to match digit number on MetaTrader data window

                if( IsFirstTick_HTF )
                  {
                    Print( "" );
                    Print( "" );
                    Print( "" ,
                        // "*** HTF downtick: " ,
                        // "SMA(5) = "          ,     DoubleToString( sma_HTF_drift_1 , 4)         , " / " ,
                        "[OnTick]>[Entry Management]>[HTF Setup]: "
                        "RSI(3) D1 [1]= "    ,     DoubleToString( rsi3_HTF_1 , 4 )             , " / " ,
                        "RSI(3) D1 [2]= "    ,     DoubleToString( rsi3_HTF_2 , 4 )             , " / " ,
                        "MACDH(12,26,9)[1]: "   ,  DoubleToString( macd_HTF_entry_hist_1 , 3)  , " / " ,
                        "MACDH(12,26,9)[2]: "   ,  DoubleToString( macd_HTF_entry_hist_X , 3)

                        // "MACDH(18,36,18)[1]: "  ,  DoubleToString( macd_HTF_exit_hist_1 , 5)    , " / " ,
                        // "MACDH(18,36,18)[2]: "  ,  DoubleToString( macd_HTF_exit_hist_X , 5)
                      );
                    Print( "" );
                    Print( "" );
                  }   // End //*** DEBUGGING ***//

                bool _debugcheckactive_2 = true ;

                if(     IsFirstTick_MTF
                    &&  _debugcheckactive_2
                    &&  ( //"2016.03.30" == TimeToStr( Time[0] , TIME_DATE )  ||
                            "2016.03.31" == TimeToStr( Time[0] , TIME_DATE )
                         && (StrToTime("19:00") <= Time[0]  && Time[0] <= StrToTime("23:59") )
                        )
                  )
                  {
                    Print( "" );
                    Print ( ""
                          "[OnTick]>[MTF Setup Sell]:" ,
                          " RSI H1 MTF: " ,
                          " Dateime[1] @ M5: ", TimeToStr( Time[1] , TIME_DATE|TIME_MINUTES ) ,
                          " RSI(6)H1[1]: " , DoubleToStr(rsi_MTF_fast_1 , 4) ,
                          " RSI(6)H1[2]: " , DoubleToStr(rsi_MTF_fast_X , 4)
                          //" RSI(9): " , DoubleToStr(rsi_MTF_slow_1 , 4)
                       );
                  } // End //*** DEBUGGING ***//

                if(     "2016.03.31" == TimeToStr( Time[0] , TIME_DATE )
                    && (StrToTime("19:00") <= Time[0]  && Time[0] <= StrToTime("23:59") )
                    && _debugcheckactive_2
                  )
                  //  From: MQL4 Reference  /  Conversion Functions / StrToTime
                  //  datetime var1,var2,var3;
                  //  var1=StrToTime("2003.8.12 17:35");  // You can use this!
                  //  var2=StrToTime("17:35");      // returns the current date with the given time
                  //  var3=StrToTime("2003.8.12");  // returns the date with the midnight time of "00:00"
                  //  2017.05.23 (0607) - Tuesday
                  {
                      Print(
                        "[OnTick]>[LTF Trigger Sell]: " ,
                        " BB Upper[2]: "  , DoubleToStr(bb_LTF_channel1_upper_2, 2 ) ,
                        " LR(30)[2]: "    , DoubleToStr(lrco_LTF_2slow_2 , 4) ,
                        " Time[1] @ M5: ", TimeToStr( Time[1] , TIME_MINUTES ) ,

                        " // ",
                        " LR(10)[1]: "    , DoubleToStr(lrco_LTF_1fast_1 , 4) ,
                        " LR(30)[1]: "    , DoubleToStr(lrco_LTF_2slow_1 , 4) ,
                        " LR(10)[2]: "    , DoubleToStr(lrco_LTF_1fast_2 , 4) ,
                        " // ",
                        " BB Upper[1]: "  , DoubleToStr(bb_LTF_channel1_upper_1, 2 )

                      );


                    // Cross Down test
                    if( rsi_MTF_fast_1 > 60.0 )
                      {

                      Print("RSI H1 > 60.0: " , DoubleToStr(rsi_MTF_fast_1 , 4));

                      if(lrco_LTF_2slow_2 >  bb_LTF_channel1_upper_2 // slow LR above upper bollinger band
                        )
                        {

                          Print("[OnTick]>DEBUG> Slow LRCO [2] is above Bollinger Band[2] ");
                          Print(" BB Upper[2]: "  , DoubleToStr(bb_LTF_channel1_upper_2, 2 ) ,
                                " LR(30)[2]: "    , DoubleToStr(lrco_LTF_2slow_2 , 4)
                                );

                          if(  (lrco_LTF_1fast_1 <  lrco_LTF_2slow_1)        // fast lr crosses down slow lr
                              &&  (lrco_LTF_1fast_2 >= lrco_LTF_2slow_2)        // fast lr touches or crosses slow lr
                            )
                            {
                              Print(" Fast LRCO crosses DOWN Slow LRCO ");
                              Print(""
                                " LR(10)[2]: "    , DoubleToStr(lrco_LTF_1fast_2 , 4) ,
                                " LR(30)[2]: "    , DoubleToStr(lrco_LTF_2slow_2 , 4) ,
                                " // ",
                                " LR(10)[1]: "    , DoubleToStr(lrco_LTF_1fast_1 , 4) ,
                                " LR(30)[1]: "    , DoubleToStr(lrco_LTF_2slow_1 , 4) ,
                                " // ",
                                " Time[1] @ M5: ", TimeToStr( Time[1] , TIME_MINUTES )

                              );
                            } // End of "if(  (lrco_LTF_1fast_1 <  lrco_LTF_2slow_1 ..."

                        } // End of "if(lrco_LTF_2slow_2 >  bb_LTF_channel1_upper_2 ..."

                      } // End of if( rsi_MTF_fast_1 > 60.0 )
                  } // End of "if( "2016.03.31" == TimeToStr( Time[0] , TIME_DATE ...."


    /*-----------------------------------------------------------------------------------*/
    /****** SETUP AND TRIGGER ******/
    /*-----------------------------------------------------------------------------------*/

    //-- Every day, zero in daily entry limit back to zero
    if (IsFirstTick_HTF)
      DailyCountEntry = 0 ;



    bool triggerBuy   = false ;
    bool triggerSell  = false ;

    /*-----------------------------------------------------------------------------------*/
    // **** HTF SETUP  ***
    /*-----------------------------------------------------------------------------------*/
    //-- HTF Setup is pooled as variable


    bool HTF_SetupType_1_LONG   = false ;
    bool HTF_SetupType_2_LONG  = false ;
    bool HTF_SetupType_1_SHORT  = false ;
    bool HTF_SetupType_2_SHORT   = false ;

    string comment_for_ticket = "" ;

    //--------------------------------------------------------------
    // All setup logic is pooled in this area
    //--------------------------------------------------------------



    // **** HTF SETUP FOR BUYING  ***
    /*-----------------------------------------------------------------------------------*/

    //-- HTF_SetupType_1_LONG
    if( TradeMode == TM_LONG )
      if( macd_HTF_entry_hist_X < 0.0 ) // deep push retracement
        if( rsi3_HTF_2 < 40.0 )         // downshoot pattern TWO DAYS AGO
          if( rsi3_HTF_1 > rsi3_HTF_2 )   // bounce up ONE DAYS AGO
        {
          HTF_SetupType_1_LONG  = true ;
        }

    //-- HTF_SetupType_2_LONG
    if( TradeMode == TM_LONG )
      if( macd_HTF_entry_hist_1 > macd_HTF_entry_hist_X )   // MACDH tick direction rule
        if( rsi3_HTF_cock_UP )                                // RSI3 HTF is cocked up
                //-- cocked up = RSI3 crossed 50 already  = above 50, because when it falls below 50
                //-- it become "Cocked Down", and Cocked Up is false
        {
          HTF_SetupType_2_LONG = true ;
        }



    // **** HTF SETUP FOR SELLING  ***
    /*-----------------------------------------------------------------------------------*/

    //-- HTF_SetupType_1_SHORT
      if ( TradeMode == TM_SHORT )
        if( macd_HTF_entry_hist_X > 0.0 )  // deep upward retracement
            if ( rsi3_HTF_2 > 60.0 )           // upshoot pattern TWO DAYS AGO
              if ( rsi3_HTF_1 < rsi3_HTF_2 )     // bounce down ONE DAYS AGO
          {
            HTF_SetupType_1_SHORT = true ;
          }

    //-- HTF_SetupType_2_SHORT
    if(TradeMode == TM_SHORT )
      if(macd_HTF_entry_hist_1 < macd_HTF_entry_hist_X)   // MACDH tick direction rule
        if(rsi3_HTF_tick_DOWN )                             // RSI3 HTF ticks down
          //-- tick down = RSI3 simply having declining direction, regardless
          //-- in overbought or oversold; both are doesn't matter
        {
          HTF_SetupType_2_SHORT = true ;
        }



    /*-----------------------------------------------------------------------------------*/
    // **** MTF SETUP  ***
    /*-----------------------------------------------------------------------------------*/
    //-- MTF Setup is pooled as variable

    bool MTF_SetupType_1_LONG     = false ;
    bool MTF_SetupType_1_SHORT    = false ;

    // I use phrase "SetupType_1_" as placeholder for new SetupType_2_, SetupType_3_
    // that might come later



    // **** MTF SETUP FOR BUYING ***
    //------------------------------------------------------------------------------------

    if( TradeMode == TM_LONG )
      if(     (rsi_MTF_fast_1 < 40.0 )
          ||  (rsi_MTF_fast_2 < 40.0 )
          ||  (rsi_MTF_fast_3 < 40.0 )
          ||  (rsi_MTF_fast_4 < 40.0 )
          // This component ensures in the past 4 hours, the price is EVER oversold
        )
        if(  // No recent overbought for BUYING
              (rsi_MTF_fast_1 < 70.0 )
          &&  (rsi_MTF_fast_2 < 70.0 )
          // This componenet ensures in the past 2 hours, the price is NOT in overbought again
          // 70 is overbought level!
          )
          {
            MTF_SetupType_1_LONG = true ;
          }
    // Why this 4 hours window rule?
    // The straightforward rule "H1 is oversold", then find a bounce off on M5 works for most
    // market situation.
    // In very jaggy market, "H1 is oversold", but the M5 does not push down enough beyond
    // Bollinger band, hence not oversold in technical manner.
    // This rule allows window of "oversold" still valid


    // **** MTF SETUP FOR SELLING ***
    //------------------------------------------------------------------------------------

    if( TradeMode == TM_SHORT )
      if(     (rsi_MTF_fast_1 > 60.0 )
          ||  (rsi_MTF_fast_2 > 60.0 )
          ||  (rsi_MTF_fast_3 > 60.0 )
          ||  (rsi_MTF_fast_4 > 60.0 )
          // This component ensures in the past 4 hours, the price is EVER overbought
        )
        if(  // No recent overSOLD for SELLING
              (rsi_MTF_fast_1 > 30.0 )
          &&  (rsi_MTF_fast_2 > 30.0 )
          // This componenet ensures in the past 2 hours, the price is NOT in oversold again
          // 30 is oversold level!
            )
            {
              MTF_SetupType_1_SHORT = true ;
            }







    /*-----------------------------------------------------------------------------------*/
    // **** BUY OPERATION  ***
    /*-----------------------------------------------------------------------------------*/

    //** PICK PRECOMPUTED HTF SETUP  **
    //----------------------------------------------------------------
    if( HTF_SetupType_1_LONG || HTF_SetupType_2_LONG )


    //-- Powertool 4 uses Weekly Bar
    //-- Weekly bar is the main direction for long.
    //-- SMA drift rule for D1 may be redundant
    //-- Or, even we use RSI(3,D1) "pointing up" as setup,
    //-- because the Weekly already guide the trend direction

    {   //-- Setup - LONG

        //*****************//
        //*** DEBUGGING ***//
        //*****************//
        if( IsFirstTick_HTF )
          {
            Print( ""
                // "*** HTF uptick: " ,
                // "SMA(5) = "          ,     DoubleToString( sma_HTF_drift_1 , 4)         , " / " ,
                // "RSI(3) D1 [1]= "    ,     DoubleToString( rsi3_HTF_1 , 2 )             , " / " ,
                // "RSI(3) D1 [2]= "    ,     DoubleToString( rsi3_HTF_2 , 2 )             , " / " ,
               // //"MACDH(12,26,9,D1)[1]: "   ,  DoubleToString( macd_HTF_entry_hist_1 , 5)  , " / " ,
               // //"MACDH(12,26,9)[2,D1]: "   ,  DoubleToString( macd_HTF_entry_hist_X , 5)  , " / " ,
                // "MACDH(18,36,18)[1]: "  ,  DoubleToString( macd_HTF_exit_hist_1 , 5)    , " / " ,
                // "MACDH(18,36,18)[2]: "  ,  DoubleToString( macd_HTF_exit_hist_X , 5)
              );
          }   // End //*** DEBUGGING ***//


        // Mark LTF with HTF Setup
        string  txtHTFmarker = "HTF_Setup_ " + TimeToStr(Time[0] , TIME_DATE|TIME_MINUTES ) ;
        ObjectCreate( txtHTFmarker , OBJ_TEXT , 0 , Time[0] , Low[1] - 40.0 * Point );
        ObjectSetText( txtHTFmarker , "o" ,7 , "Arial" , clrDarkGreen );

        // Coloring reference
        // MQL4 Reference  /  Standard Constants, Enumerations and Structures  /  Objects Constants / Web Colors



        //** MTF SETUP  **
        //----------------------------------------------------------------

        if(// MTF SETUP
              //rsi_MTF_fast_1 < 40.0                              // RSI is "dip"
              MTF_SetupType_1_LONG
          )
          {

            //** MARKER for MTF on M5  **
            //----------------------------------------------------------------
            string  txtMTFMarker = "MTF_Setup_ " + TimeToStr(Time[0] , TIME_DATE|TIME_MINUTES ) ;
            ObjectCreate( txtMTFMarker , OBJ_TEXT , 0 , Time[0] , Low[1] - 30.0 * Point );
            ObjectSetText( txtMTFMarker , "x" ,8 , "Arial" , clrOlive );



            //** LTF TRIGGER  **
            //----------------------------------------------------------------

            //-- BREAK THIS LOGIC INTO SEQUENTIAL DECISION ;
            //-- NOT INTO ROLLED-UP-IN-ONE-IF DECISION
            //-- DO THE SAME BREAKING UP FOR LONG-SIDE

            //-- Why: this is to ensure computer processes chunks of logic
            //-- in a sequential manner, hence more robust than processing in
            //-- a rolled-up manner.
            //-- Previous rolled-up processing causes some valid situation skipped!

            bool  slowLR_BELOW_lowerBollingerBand_bar2  = false ;
            bool  fastLR_CROSSES_UP_slowLR_bar1         = false ;
            bool  fastLR_TOUCHESORBELOW_slowLR_bar2     = false ;
            bool  fastLR_TURN_UP                        = false ;
            //-- The naming is self-explanatory

            //-- Break the logic into a sequential chunks, and allocate each result in
            //-- individual variable
            slowLR_BELOW_lowerBollingerBand_bar2  = (lrco_LTF_2slow_2 <  bb_LTF_channel2_lower_2 ) ;
            fastLR_CROSSES_UP_slowLR_bar1         = (lrco_LTF_1fast_1 >  lrco_LTF_2slow_1)        ;
            fastLR_TOUCHESORBELOW_slowLR_bar2     = (lrco_LTF_1fast_2 <= lrco_LTF_2slow_2)        ;
            fastLR_TURN_UP                        = (lrco_LTF_1fast_1 > lrco_LTF_1fast_2)         ;

            if(     slowLR_BELOW_lowerBollingerBand_bar2
                &&  fastLR_CROSSES_UP_slowLR_bar1
                &&  fastLR_TOUCHESORBELOW_slowLR_bar2
                &&  fastLR_TURN_UP            //-- This criteria is not used
              )
              {
                // LTF TRIGGER
                triggerBuy = true ;
                EntrySignalCountBuy++ ;


                // Draw Up arrow
                DrawArrowUp("Up"+Bars , Low[1]-10*Point , clrYellow );

                Print("");    //-- allow one row above
                Print(  "[OnTick]: " ,
                  "*** TRIGGER BUY ****" , " Entry Signal Buy: #" ,
                  EntrySignalCountBuy
                  );
                if( HTF_SetupType_1_LONG )
                  Print("*** Setup is due to HTF_SetupType_1_LONG ***");
                if( HTF_SetupType_2_LONG )
                  Print("*** Setup is due to HTF_SetupType_2_LONG ****");


                //-- Comment for entry
                //-- The comment is to mark what condition causing entry

                if ( HTF_SetupType_1_LONG )
                  comment_for_ticket = "HTF_SetupType_1_LONG";
                else if ( HTF_SetupType_2_LONG )
                  comment_for_ticket = "HTF_SetupType_2_LONG" ;



              //*****************//
              //*** DEBUGGING ***//
              //*****************//
              if( IsFirstTick_MTF )
                {
                  Print ( ""
                        "[OnTick]>[MTF Setup Buy]: " ,
                        "---RSI MTF dip under 40: " ,
                          " Datetime [1] @ M5: ", TimeToStr( Time[1] , TIME_DATE|TIME_MINUTES ) ,
                          " RSI(6)[1]: " , DoubleToStr(rsi_MTF_fast_1 , 2) ,
                          " RSI(6)[2]: " , DoubleToStr(rsi_MTF_fast_X , 2)
                        //"RSI(9): " , DoubleToStr(rsi_MTF_slow_1 , 4)
                     );
                } // End //*** DEBUGGING ***//

                Print( ""
                  "[OnTick]>[LTF Trigger Buy]: " ,
                  "BB Upper[2]: "  , DoubleToStr(bb_LTF_channel1_upper_2, 6 ) , " / " ,
                  "BB Lower[2]: "  , DoubleToStr(bb_LTF_channel2_lower_2, 6) , " / " ,
                  "LR(10)[1]: "    , DoubleToStr(lrco_LTF_1fast_1 , 5) , " / " ,
                  "LR(30)[1]: "    , DoubleToStr(lrco_LTF_2slow_1 , 5) , " / " ,
                  "LR(10)[2]: "    , DoubleToStr(lrco_LTF_1fast_2 , 5) , " / " ,
                  "LR(30)[2]: "    , DoubleToStr(lrco_LTF_2slow_2 , 5)
                );


              } // End of "if( slowLR_BELOW_lowerBollingerBand_bar2 &&  fastLR_CROSSES_UP_slowLR_bar1 ..


          } // End of "if(rsi_MTF_fast_1 < 40.0"

    } // End of if( (macd_HTF_entry_hist_1 ... ) : Setup and Trigger for entry BUY

    /*-----------------------------------------------------------------------------------*/
    // **** SELL OPERATION  ***
    /*-----------------------------------------------------------------------------------*/


    else if(

        //** PICK PRECOMPUTED HTF SETUP  **
        //----------------------------------------------------------------
        HTF_SetupType_1_SHORT  ||
        HTF_SetupType_2_SHORT
        )


    //-- Powertool 4 uses Weekly Bar
    //-- Weekly bar is the main direction for short.
    //-- SMA drift rule for D1 may be redundant
    //-- Or, even we use RSI(3,D1) "pointing down" as setup,
    //-- because the Weekly already guide the trend direction

    { // Setup - SHORT

        //*****************//
        //*** DEBUGGING ***//
        //*****************//
        // if( IsFirstTick_HTF )
          // {
            // Print( "" );
            // Print( "" );
            // Print( "" ,
                // "*** HTF downtick: " ,
                // "SMA(5) = "          ,     DoubleToString( sma_HTF_drift_1 , 4)         , " / " ,
                // "[OnTick]>[Entry Management]>[HTF Setup]: "
                // "RSI(3) D1 [1]= "    ,     DoubleToString( rsi3_HTF_1 , 2 )             , " / " ,
                // "RSI(3) D1 [2]= "    ,     DoubleToString( rsi3_HTF_2 , 2 )             , " / " ,
                // "MACDH(12,26,9)[1]: "   ,  DoubleToString( macd_HTF_entry_hist_1 , 5)  , " / " ,
                // "MACDH(12,26,9)[2]: "   ,  DoubleToString( macd_HTF_entry_hist_X , 5)

                // "MACDH(18,36,18)[1]: "  ,  DoubleToString( macd_HTF_exit_hist_1 , 5)    , " / " ,
                // "MACDH(18,36,18)[2]: "  ,  DoubleToString( macd_HTF_exit_hist_X , 5)
              // );
            // Print( "" );
            // Print( "" );
          // }   // End //*** DEBUGGING ***//


        // Mark LTF with HTF Setup
        string  txtHTFmarker = "HTF_Setup_ " + TimeToStr(Time[0] , TIME_DATE|TIME_MINUTES ) ;
        ObjectCreate( txtHTFmarker , OBJ_TEXT , 0 , Time[0] , High[1] + 40.0 * Point );
        ObjectSetText( txtHTFmarker , "o" ,7 , "Arial" , clrDarkGreen );

        // Coloring reference
        // MQL4 Reference  /  Standard Constants, Enumerations and Structures  /  Objects Constants / Web Colors



        //** MTF SETUP  **
        //----------------------------------------------------------------

        if(// MTF SETUP
              // rsi_MTF_fast_1 > 60.0                               // RSI is "pounce up"
              MTF_SetupType_1_SHORT == true
          )
          {

            //** MARKER for MTF on M5  **
            //----------------------------------------------------------------
            string  txtMTFMarker = "MTF_Setup_ " + TimeToStr(Time[0] , TIME_DATE|TIME_MINUTES ) ;
            ObjectCreate( txtMTFMarker , OBJ_TEXT , 0 , Time[0] , High[1] + 30.0 * Point );
            ObjectSetText( txtMTFMarker , "x" ,8 , "Arial" , clrOlive );



            //** LTF TRIGGER  **
            //----------------------------------------------------------------

            //-- BREAK THIS LOGIC INTO SEQUENTIAL DECISION ;
            //-- NOT INTO ROLLED-UP-IN-ONE-IF DECISION
            //-- DO THE SAME BREAKING UP FOR LONG-SIDE

            //-- Why: this is to ensure computer processes chunks of logic
            //-- in a sequential manner, hence more robust than processing in
            //-- a rolled-up manner.
            //-- Previous rolled-up processing causes some valid situation skipped!

            bool  slowLR_ABOVE_upperBollingerBand_bar2  = false ;
            bool  fastLR_CROSSES_DOWN_slowLR_bar1       = false ;
            bool  fastLR_TOUCHESORABOVE_slowLR_bar2     = false ;
            bool  fastLR_TURN_DOWN                      = false ;
            //-- The naming is self-explanatory

            //-- Break the logic into a sequential chunks, and allocate each result in
            //-- individual variable
            slowLR_ABOVE_upperBollingerBand_bar2  = (lrco_LTF_2slow_2 >  bb_LTF_channel1_upper_2) ;
            fastLR_CROSSES_DOWN_slowLR_bar1       = (lrco_LTF_1fast_1 <  lrco_LTF_2slow_1)        ;
            fastLR_TOUCHESORABOVE_slowLR_bar2     = (lrco_LTF_1fast_2 >= lrco_LTF_2slow_2)        ;
            fastLR_TURN_DOWN                      = (lrco_LTF_1fast_1 < lrco_LTF_1fast_2)         ;

            if(     slowLR_ABOVE_upperBollingerBand_bar2
                &&  fastLR_CROSSES_DOWN_slowLR_bar1
                &&  fastLR_TOUCHESORABOVE_slowLR_bar2

              )
              {
                // LTF TRIGGER
                triggerSell = true ;
                EntrySignalCountSell++ ;


                // Draw Up arrow
                DrawArrowDown("Dn"+Bars , High[1]+10*Point , clrYellow );

                Print("");    //-- allow one row above
                Print(  "[OnTick]: " ,
                  "*** TRIGGER SELL****" , " Entry Signal Sell: #" ,
                  EntrySignalCountSell
                  );
                if( HTF_SetupType_1_SHORT )
                  Print("*** Setup is due to HTF_SetupType_1_SHORT ***");
                if( HTF_SetupType_2_SHORT )
                  Print("*** Setup is due to HTF_SetupType_2_SHORT ****");


                //-- Comment for entry
                //-- The comment is to mark what condition causing entry

                if ( HTF_SetupType_1_SHORT )
                  comment_for_ticket = "HTF_SetupType_1_SHORT";
                else if ( HTF_SetupType_2_SHORT )
                  comment_for_ticket = "HTF_SetupType_2_SHORT" ;



                //*****************//
                //*** DEBUGGING ***//
                //*****************//
                if( IsFirstTick_MTF )
                  {
                    Print ( ""
                          "[OnTick]>[MTF Setup Sell]:" ,
                          " RSI MTF bounce up above 60: " ,
                          " Datetime [1] @ M5: ", TimeToStr( Time[1] , TIME_DATE|TIME_MINUTES ) ,
                          " RSI(6)[1]: " , DoubleToStr(rsi_MTF_fast_1 , 2) ,
                          " RSI(6)[2]: " , DoubleToStr(rsi_MTF_fast_X , 2)
                          //" RSI(9): " , DoubleToStr(rsi_MTF_slow_1 , 4)
                       );
                  } // End //*** DEBUGGING ***//

                      Print(
                        "[OnTick]>[LTF Trigger Sell]: " ,
                        " BB Upper[2]: "  , DoubleToStr(bb_LTF_channel1_upper_2, 6 ) , " / " ,
                        " BB Lower[2]: "  , DoubleToStr(bb_LTF_channel2_lower_2, 6) , " / " ,
                        " LR(10)[1]: "    , DoubleToStr(lrco_LTF_1fast_1 , 5) , " / " ,
                        " LR(30)[1]: "    , DoubleToStr(lrco_LTF_2slow_1 , 5) , " / " ,
                        " LR(10)[2]: "    , DoubleToStr(lrco_LTF_1fast_2 , 5) , " / " ,
                        " LR(30)[2]: "    , DoubleToStr(lrco_LTF_2slow_2 , 5)
                      );


              } // End of "if(slowLR_ABOVE_upperBollingerBand_bar2 &&  fastLR_CROSSES_DOWN_slowLR_bar1"


          } // End of "if(rsi_MTF_fast_1 > 60.0)"

    } // End of if( (macd_HTF_entry_hist_1 ... ) : Setup and Trigger for entry SELL


    //*****************//
    //*** DEBUGGING ***//
    //*****************//
    if( IsFirstTick_HTF )
    {
      // Print("[OnTick]: " ,
          // "ExclZone_In: " , BoolToStr(ExclZone_In)
           // );
    }



  /*-----------------------------------------------------------------------------------*/
  /****** EXECUTION - ENTRY ******/
  /*-----------------------------------------------------------------------------------*/

  if(
      CalculateCurrentOrders( Symbol() ) < MaxPositions
        && (!ExclZone_In)
        && (EntrySignalCountBuy <= EntrySignalCountThreshold)
        && (TradeMode == TM_LONG )
        && triggerBuy
    )
  {

    /*-----------------------------------------------------------------------------------*/
    /****** EXECUTE_ENTRY_BUY ******/
    /*-----------------------------------------------------------------------------------*/

    Execute_Entry_Buy_PMultiple( MaxPositions , atr_LTF_36bar_1 , comment_for_ticket );

  }
  else if (
      CalculateCurrentOrders( Symbol() ) < MaxPositions
        && (!ExclZone_In)
        && (EntrySignalCountSell <= EntrySignalCountThreshold)
        && (TradeMode == TM_SHORT )
        && triggerSell
    )
  {

    /*-----------------------------------------------------------------------------------*/
    /****** EXECUTE_ENTRY_SELL ******/
    /*-----------------------------------------------------------------------------------*/

    Execute_Entry_Sell_PMultiple( MaxPositions , atr_LTF_36bar_1 , comment_for_ticket);

  }





  //+-------------------------------------------------------------------------------------------------+
  //| Reporting on First Tick HTF                                                                      |
  //+-------------------------------------------------------------------------------------------------+

  if( IsFirstTick_HTF )
    REPORT_Equity_PeakAndDrawdown(
        IsFirstTick_HTF ,
        PeakEquity          ,
        DrawdownEquity      ,
        DrawdownPercent     ,
        DrawdownMaxEquity   ,
        DrawdownMaxPercent  ,
        RecoveryRatio
                    );





    /***********************************************************************************************/
    /***   ENDING BLOCK OF ONTICK()   ***/
    /***********************************************************************************************/

    // LAST BLOCK - TTF
    TTF_Barname_Prev = TTF_Barname_Curr ;

    // LAST BLOCK - HTF
    HTF_Barname_Prev = HTF_Barname_Curr ;


    // LAST BLOCK - MTF
    MTF_Barname_Prev = MTF_Barname_Curr ;


    // LAST BLOCK - LTF
    LTF_Barname_Prev = LTF_Barname_Curr ;



  }     // *******   End of OnTick()   *******







//+*******************************************************************************************************************+

//+*******************************************************************************************************************+


