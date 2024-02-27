trap control_c SIGINT

function control_c()
{
    stty echo
    exit 0
}

function play_game() {
clear
debugLines=11
for (( i = 0; i < $debugLines; i++ )) ; do
    echo -en '\n'
done
verbose=false
# Handle flags
function vPrint(){
    if [ $verbose = true ] ; then
        echo -en '\033['$((debugLines-$1))'A'
        echo -en "${@:2}"
        echo -e '\033['$((debugLines-$1-1))'B'
    fi
}
while getopts "v" opt; do
    case $opt in
        v)
            verbose=true
            vPrint 0 "verbose mode"
            ;;
        *)
            echo "invalid command"
            ;;
    esac
done
# shift flags away
shift $(($OPTIND - 1))

if [ $verbose = false ] ; then
    echo -en '\033['$debugLines'A'
    # echo -e 'test\ntest\ntest\ntest\ntest\ntest\ntest\ntest\n'
fi

# Initialize values
# Game window dimensions
numRows=$1
numCols=$2
gridSize=$((numRows * numCols))
vPrint 1 $numRows rows X $numCols cols = $gridSize cells
# Game time params. Clock in milliseconds
clock=25
frameNo=0
# Player moves every `playerMult` frames, blink value is updated every `blinkMult` frames
startingPlayerMult=8
playerMult=$startingPlayerMult
blinkMult=4
# food "blinks" 3-2-1-2-3 changing from dark to light to dark shaded block.
blink=3
blinkOp='-'
# Player info
# Player is represented by positive integer(s)
# Head leaves behind tail cells which decay down to 0, disappearing
score=0
playerLen=1
playerX=$((RANDOM % numCols))
playerY=$((RANDOM % numRows))
playerDir='right'
decayRate=0

if (( (playerX-(numCols/2))**2 < (playerY-(numRows / 2)) ** 2))
then
    if ((playerY < (numRows / 2))); then
        playerDir='down'
    else
        playerDir='up'
    fi
else
    if ((playerX < (numCols / 2))); then
        playerDir='right'
    else
        playerDir='left'
    fi
fi
vPrint 2 player $playerX , $playerY, $playerDir
# vPrint 4 $(((playerX-(numCols/2))**2)) '<' $(((playerY-(numRows/2))**2)) " " $(((playerX-(numCols/2)) ** 2 < (playerY-(numRows / 2)) ** 2))
# vPrint 5 "X " $((playerX)) '<' $((numCols / 2)) ' ' $((playerX < (numCols / 2)))
# vPrint 6 "Y " $((playerY)) '<' $((numRows/2)) ' ' $((playerY < (numRows / 2)))
function player_loc(){
    echo -n $((playerX + playerY * numCols))
}
# Food info
# Food is represented by a -1
foodX=0
foodY=0
function food_loc(){
    echo -n $((foodX + foodY * numCols))
}
function spawn_food(){
foodX=$((RANDOM % numCols))
foodY=$((RANDOM % numRows))
vPrint 4 'food ' $foodX ', ' $foodY
gameState[$(food_loc)]='-1'
}
# Game State
gameState=()
screenState=()
for (( i = 0; i <= $gridSize; i++ )) ; do
    gameState+=( 0 )
    screenState+=( ' ' )
done
spawn_food
screenState[$(food_loc)]='\u259'$blink
gameState[$(player_loc)]=$playerLen
screenState[$(player_loc)]='\u2588'

# Define Printing functions
function print_line(){
    # $1 can be either "t","m", or "b"
    leftEdge='\u2551'
    rightEdge='\u2551'
    case $1 in
        t)
            leftEdge='\u2554'
            rightEdge='\u2557' ;;
        m)
            leftEdge='\u2560'
            rightEdge='\u2563' ;;
        b)
            leftEdge='\u255A'
            rightEdge='\u255D' ;;
    esac
    line=''
    for (( col = 0; col < $numCols; col++ )); do
        line+='\u2550\u2550'
    done
    echo -n $leftEdge$line$rightEdge'\n'
}

function print_state() {
screen=""
screen+="$(print_line t)"
screen+="$(printf '\u2551score:%-*s\u2551' $((numCols * 2 - 6)) ${score})"'\n'
screen+="$(print_line m)"
for (( row = 0; row < $numRows; row++ )); do
    screen+='\u2551'
    for (( col = 0; col < $numCols; col++ )); do
        # printf " %03d " ${gameState[$((row * numCols + col))]}
        screen+="${screenState[$((row * numCols + col))]}${screenState[$((row * numCols + col))]}"
    done
    screen+='\u2551\n'
done
screen+="$(print_line b)"
screen+="\033[$((numRows+4))A\033[${numCols}D"
echo -en "$screen"
}

# Initialize Game
print_state

function input_cycle() {
    unset curPress
    endTime=$(($(date +%s%3N) + clock))
    while [[ $(date +%s%3N) < $endTime ]]; do
        read -es -a curPress -n 1 -t 0.001
        if [[ "$curPress" =~ [wasdq] ]]; then
            keyPress=$curPress
        fi
    done
}

# Run Game
function advance_state(){
    input_cycle
    vPrint 5 'Frame ' $frameNo
    vPrint 3 keyPress "${keyPress}"
    case $keyPress in
        # Up Arrow `[A` will fall through to next case without checking that case's condition
        # Nevermind, arrow keys are too complicated and I'll worry about them later
        # [A);&
        w)
            if [ $playerDir != 'down' ] ; then
                playerDir='up'
            fi ;;
        # [B);&
        s)
            if [ $playerDir != 'up' ] ; then
                playerDir='down'
            fi ;;
        # [D);&
        a)
            if [ $playerDir != 'right' ] ; then
                playerDir='left'
            fi ;;
        # [C);&
        d)
            if [ $playerDir != 'left' ] ; then
                playerDir='right'
            fi ;;
        q)
            echo -e "\033[$((numRows+4))B"
            stty "$old_tty_settings"      # Restore old settings.
            exit 0 ;;
    esac
    
    # new screen to show
    screenState=()
    # for (( i = 0; i <= $gridSize; i++ )) ; do
    #     # gameState+=( 0 )
    #     screenState+=( '\u259'$blink )
    # done
    # print_state
    # Update blink value if necessary
    vPrint 6 $((frameNo % blinkMult))
    if [[ $((frameNo % blinkMult)) = 0 ]]; then
        blink=$((blink${blinkOp}1))
        vPrint 7 'Blink ' $blink
        vPrint 8 'BlinkOp ' $blinkOp
        case $blink in
            1)
                blinkOp='+' ;;
            3)
                blinkOp='-' ;;
        esac
    fi
    # Update player data if necessary
    if [[ $((frameNo % playerMult)) = 0 ]]; then
        decayRate=1

        # Calculate player destination
        case $playerDir in
            up)
                playerX=$((playerX % numCols))
                playerY=$(((playerY + numRows - 1) % numRows)) ;;
            down)
                playerX=$((playerX % numCols))
                playerY=$(((playerY + 1) % numRows)) ;;
            left)
                playerX=$(((playerX + numCols - 1) % numCols))
                playerY=$((playerY % numRows)) ;;
            right)
                playerX=$(((playerX + 1) % numCols))
                playerY=$((playerY % numRows)) ;;
        esac

        # Check outcome of going to destination
        case ${gameState[$(player_loc)]} in
            -1)
                ((playerLen++))
                ((score++))
                playerMult=$((startingPlayerMult - score / 10))
                playerMult=$((playerMult<1 ? 1 : playerMult))
                spawn_food ;;
            0)
                : ;;
            *)
                echo -e "\033[$((numRows+4))BGame Over!"
                stty "$old_tty_settings"      # Restore old settings.
                exit 0 ;;
        esac
        vPrint 9 'gameState ' ${gameState[$(player_loc)]} ' '
        # Head gets one extra because it will immediately be decremented
        gameState[$(player_loc)]=$((playerLen + 1))
    else
        decayRate=0
    fi
    # Build screen and decay head & tails
    for (( i = 0; i <= $gridSize; i++ )) ; do
        val=${gameState[$i]}
        char=' '
        case $val in
            -1)
                char='\u259'$blink ;;
            0)
                char=' ' ;;
            *)
                char='\u2588'
                gameState[$i]=$((${gameState[$i]} - decayRate)) ;;
        esac
        screenState+=( "$char" )
    done
    print_state
    frameNo=$(( (frameNo % (playerMult * blinkMult)) + 1 ))
}

old_tty_settings=$(stty -g)   # Save old settings.
stty -echo
while true; do
    advance_state
done
}

play_game $@
