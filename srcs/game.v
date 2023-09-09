// Number Guessing Game
// Authors: Alicja Mahr, Jackson Kahn
// Class: ENG EC 311
// Professor Tali Moreshet

module main(P1_SCORE, P2_SCORE, DISP_Out, AN_Out, DIP, PROCEED_BTN, AI_RST_BTN, CLK, RST);
    input [15:0] DIP;
    input PROCEED_BTN, AI_RST_BTN, CLK, RST;
    
    reg GAMEMODE; // 0 = vs FPGA, 1 = vs Human
    
    // 16^4 is the total number of combinations.
    // 2^16 == 16^4, therefore allowing for as many rounds
    // as possible, assuming no duplicates
    reg [15:0] ROUND_COUNT;

    reg [15:0] P1; // Player 1's correct number
    reg [15:0] P2; // Player 2's correct number
    reg [15:0] GUESS; // Current guess
    
    // Score Storage
    output reg [7:0] P1_SCORE;
    output reg [7:0] P2_SCORE;

    // Used for guessing
    reg [3:0] guess_correct;
    reg [3:0] guess_misplaced;
    reg [3:0] correct_digit;
    reg [3:0] guessed_digit;
    reg [3:0] searched_digit;

    // Used in for loops
    integer i, j; 

    // Used to control logic flow
    reg [2:0] STATE;
    parameter S_MODE = 3'b000,
        S_INPUT = 3'b001,
        S_GUESS = 3'b010,
        S_CHECK = 3'b011,
        S_FINISH = 3'b100;
    
    reg [2:0] FIN_STATE; // Display state for S_FINISH
    parameter FIN_S_WIN = 3'b000,
        FIN_S_P1 = 3'b001,
        FIN_S_P2 = 3'b010,
        FIN_S_DISP_ROUND = 3'b011,
        FIN_S_CONT = 3'b100;

    reg TURN; // 0 = Player 1, 1 = Player 2
    
    reg DISP_PAUSE; // 0 = No Pause, 1 = Pause until counted
    reg [3:0] DISP_PAUSE_COUNT;
    parameter DISP_PAUSE_MAX = 2**4-1;

    // 7-segment display
    parameter D_ZERO = 7'b0111111,
        D_ONE   = 7'b0000110,
        D_TWO   = 7'b1011011,
        D_THREE = 7'b1001111,
        D_FOUR  = 7'b1100110,
        D_FIVE  = 7'b1101101,
        D_SIX   = 7'b1111101,
        D_SEVEN = 7'b0000111,
        D_EIGHT = 7'b1111111,
        D_NINE  = 7'b1101111,
        D_A     = 7'b1110111,
        D_B     = 7'b1111100,
        D_C     = 7'b0111001,
        D_D     = 7'b1011110,
        D_E     = 7'b1111001,
        D_F     = 7'b1110001,
        D_S     = 7'b1101101, // For "SET"
        D_T     = 7'b1111000,
        D_G     = 7'b0111101, // For "GUE" - GUESS
        D_U     = 7'b0111110,
        D_P     = 7'b1110011,
        D_L     = 7'b0111000,
        D_N     = 7'b1010100,
        D_R     = 7'b1010000;
        

    reg [55:0] DISP_In;
    reg [7:0] AN_In;
    output [7:0] AN_Out;
    output [6:0] DISP_Out;
    SevenSegmentLED disp(.clk(CLK), .rst(RST), .AN_In(AN_In), .C_In(DISP_In), .AN_Out(AN_Out), .C_Out(DISP_Out));
    
    // Divide CLK for FPGA
    wire DIV_CLOCK;
    clk_divider clkd(.clk_in(CLK), .rst(RST), .divided_clk(DIV_CLOCK));

    // Debounce the proceed button
    wire DPBTN;
    debouncer d_btn(.button_push(PROCEED_BTN), .clk(DIV_CLOCK), .clean(DPBTN));
    
    // Debouncce the AI RST button
    wire DAIBTN;
    debouncer d_aibtn(.button_push(AI_RST_BTN), .clk(DIV_CLOCK), .clean(DAIBTN));
    
    // Initalise RNG for AI gamemode
    reg RNG_LOAD;
    reg [15:0] RNG_SEED;
    wire [15:0] RNG_OUT;
    PRNG rng_gen(CLK, RST, RNG_LOAD, RNG_SEED, RNG_OUT);

    // Convert binary to 7-segment display
    function [6:0] binTo7Seg;
        input [3:0] bin;
        begin
            case (bin)
                4'b0001: binTo7Seg = D_ONE;
                4'b0010: binTo7Seg = D_TWO;
                4'b0011: binTo7Seg = D_THREE;
                4'b0100: binTo7Seg = D_FOUR;
                4'b0101: binTo7Seg = D_FIVE;
                4'b0110: binTo7Seg = D_SIX;
                4'b0111: binTo7Seg = D_SEVEN;
                4'b1000: binTo7Seg = D_EIGHT;
                4'b1001: binTo7Seg = D_NINE;
                4'b1010: binTo7Seg = D_A;
                4'b1011: binTo7Seg = D_B;
                4'b1100: binTo7Seg = D_C;
                4'b1101: binTo7Seg = D_D;
                4'b1110: binTo7Seg = D_E;
                4'b1111: binTo7Seg = D_F;
                default: binTo7Seg = D_ZERO;
            endcase
        end
    endfunction

    // Returns the bits of the given digit
    function [3:0] getDigit;
        input [15:0] num;
        input [3:0] digit;
        begin
            case (digit)
                4'b0000: getDigit = num[3:0];
                4'b0100: getDigit = num[7:4];
                4'b1000: getDigit = num[11:8];
                4'b1100: getDigit = num[15:12];
                default: getDigit = 4'b0000;
            endcase
        end
    endfunction

    always @ (posedge DIV_CLOCK or posedge RST or posedge DAIBTN) begin
        if (RST) begin
            GAMEMODE <= 0;
            ROUND_COUNT <= 0;
            
            P1 <= 0;
            P2 <= 0;
            
            P1_SCORE <= 0;
            P2_SCORE <= 0;
            
            GUESS <= 0;
            
            TURN <= 0;
            STATE <= S_MODE;
            FIN_STATE <= FIN_S_WIN;
            
            DISP_In <= 0;
            AN_In <= 8'b11111111;

            guess_correct <= 0;
            guess_misplaced <= 0;
            correct_digit <= 0;
            guessed_digit <= 0;
            searched_digit <= 0;
            
            DISP_PAUSE <= 0;
            DISP_PAUSE_COUNT <= 0;
            
            RNG_SEED <= 15'b0101110111101100;
            RNG_LOAD <= 1;

            i <= 0;
            j <= 0;
        // If AI RST btn is held, and we're playing against AI, and we're actively playing
        end else if (DAIBTN && !GAMEMODE && (STATE == S_GUESS || STATE == S_CHECK)) begin
            DISP_In <= {
                binTo7Seg(P2[15:12]),
                binTo7Seg(P2[11:8]),
                binTo7Seg(P2[7:4]),
                binTo7Seg(P2[3:0]),
                7'b0,
                7'b0,
                D_A,
                D_ONE
            };
            
            DISP_PAUSE <= 1;
            STATE <= S_MODE;
        end else if (DISP_PAUSE) begin
            if (DISP_PAUSE_COUNT >= DISP_PAUSE_MAX) begin
                DISP_PAUSE <= 0;
                DISP_PAUSE_COUNT <= 0;
            end else DISP_PAUSE_COUNT <= DISP_PAUSE_COUNT + 1;
        end else begin
            case (STATE)
                // Mode Select
                S_MODE: begin
                    if (DPBTN) begin
                        // Start the RNG clock when the mode is selected
                        RNG_LOAD <= 0;
                        GAMEMODE <= DIP[0];
                        STATE <= S_INPUT;
                    end else begin
                        DISP_In <= DIP[0] ? {
                            D_P,
                            D_L,
                            D_A,
                            D_FOUR,
                            D_E,
                            D_R,
                            7'b0,
                            7'b0
                        } : {
                            D_A,
                            D_ONE,
                            7'b0,
                            7'b0,
                            7'b0,
                            7'b0,
                            7'b0,
                            7'b0
                        };
                    end
                end
                // Setup
                S_INPUT: begin
                    if (!GAMEMODE) begin
                        P2 <= RNG_OUT;
                        STATE <= S_GUESS;
                    end else if (DPBTN) begin
                        if (TURN == 0) P1 <= DIP;
                        else begin
                            P2 <= DIP;
                            STATE <= S_GUESS;
                        end
                        TURN <= ~TURN;
                    end
                    else begin
                        DISP_In <= {
                            binTo7Seg(DIP[15:12]),
                            binTo7Seg(DIP[11:8]),
                            binTo7Seg(DIP[7:4]),
                            binTo7Seg(DIP[3:0]),
                            D_S,
                            D_E,
                            D_T,
                            binTo7Seg(TURN)
                        };
                    end
                end
                // Guess
                S_GUESS: begin
                    if (DPBTN) begin
                        GUESS <= DIP;
                        STATE <= S_CHECK;
                        ROUND_COUNT <= ROUND_COUNT + 1;
                    end
                    else begin
                        DISP_In <= {
                            binTo7Seg(DIP[15:12]),
                            binTo7Seg(DIP[11:8]),
                            binTo7Seg(DIP[7:4]),
                            binTo7Seg(DIP[3:0]),
                            D_G,
                            D_U,
                            D_E,
                            binTo7Seg(TURN)
                        };
                    end
                end
                // Check
                S_CHECK: begin
                    if (GUESS == (TURN == 0 ? P2 : P1)) STATE <= S_FINISH;
                    else begin
                        // Performs a grid search where the diagonals are correct and other spaces are misplaced.
                        // Allows for higher numbers than 4 if duplicates are present.
                        // Discussed and cleared with Alperen
                        for (i = 0; i < 16; i = i + 4) begin
                            correct_digit = getDigit(TURN == 0 ? P2 : P1, i);
                            guessed_digit = getDigit(GUESS, i);
                            if (correct_digit == guessed_digit) begin
                                guess_correct = guess_correct + 1;
                            end
                            else begin
                                for (j = 0; j < 16; j = j + 4) begin
                                    searched_digit = getDigit(TURN == 0 ? P2 : P1, j);
                                    if (correct_digit == searched_digit) begin
                                        guess_misplaced = guess_misplaced + 1;
                                    end
                                end
                            end
                        end
                        // Display the number of correct digits and the number of misplaced digits
                        DISP_In <= {
                            D_C,
                            binTo7Seg(guess_correct),
                            D_E,
                            binTo7Seg(guess_misplaced),
                            7'b0000000,
                            7'b0000000,
                            7'b0000000,
                            binTo7Seg(TURN)
                        };
                        
                        // Hold display
                        DISP_PAUSE <= 1;

                        // Reset the guess
                        GUESS <= 0;
                        guess_correct <= 0;
                        guess_misplaced <= 0;
                        STATE <= S_GUESS;
                        // Only change terms if we're playing against a human
                        if (GAMEMODE) TURN <= ~TURN;
                    end
                end
                // Finish
                S_FINISH: begin
                    case (FIN_STATE)
                        FIN_S_WIN: begin
                            DISP_In <= {
                                D_S,
                                D_U,
                                D_C,
                                D_C,
                                D_E,
                                D_S,
                                D_S,
                                GAMEMODE ? binTo7Seg(TURN) : 7'b0
                            };
                            
                            DISP_PAUSE <= 1;
                            // Skip P1 if we're playing against the AI
                            FIN_STATE <= GAMEMODE ? FIN_S_P1 : FIN_S_P2;
                        end
                        FIN_S_P1: begin
                            DISP_In <= {
                                binTo7Seg(P1[15:12]),
                                binTo7Seg(P1[11:8]),
                                binTo7Seg(P1[7:4]),
                                binTo7Seg(P1[3:0]),
                                7'b0,
                                7'b0,
                                D_P,
                                binTo7Seg(1)
                            };
                            
                            DISP_PAUSE <= 1;
                            FIN_STATE <= FIN_S_P2;
                        end
                        FIN_S_P2: begin
                            DISP_In <= {
                                binTo7Seg(P2[15:12]),
                                binTo7Seg(P2[11:8]),
                                binTo7Seg(P2[7:4]),
                                binTo7Seg(P2[3:0]),
                                7'b0,
                                7'b0,
                                // Change to say AI if we're playing against it
                                GAMEMODE ? D_P : D_A,
                                GAMEMODE ? binTo7Seg(2) : D_ONE
                            };
                            
                            DISP_PAUSE <= 1;
                            FIN_STATE <= GAMEMODE ? FIN_S_CONT : FIN_S_DISP_ROUND;
                        end
                        FIN_S_DISP_ROUND: begin
                            DISP_In <= {
                                D_R,
                                D_N,
                                D_D,
                                7'b0,
                                binTo7Seg(ROUND_COUNT[15:12]),
                                binTo7Seg(ROUND_COUNT[11:8]),
                                binTo7Seg(ROUND_COUNT[7:4]),
                                binTo7Seg(ROUND_COUNT[3:0])
                            };
                            
                            DISP_PAUSE <= 1;
                            FIN_STATE <= FIN_S_CONT;
                        end
                        FIN_S_CONT: begin
                            // Handle player score if playing against human
                            if (GAMEMODE) begin
                                // Increase score for winner
                                if (TURN == 0) P1_SCORE = P1_SCORE + 1;
                                else P2_SCORE = P2_SCORE + 1;
                            end
                            
                            // Restart the game
                            TURN <= 0;
                            ROUND_COUNT <= 0;
                            FIN_STATE <= FIN_S_WIN;
                            // If AI, go back to Mode Select, else, back to input
                            STATE <= GAMEMODE ? S_INPUT : S_MODE;
                        end
                    endcase
                end
            endcase
        end
    end
endmodule

//Add score systsem which displays total score, resets on RST
//Need to make singleplayer mode f
