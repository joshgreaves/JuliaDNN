include("./JoshNet.jl")
include("./DataPrep.jl")
include("./Arff.jl")

using Plots

importall JoshNet
import DataPrep
import Arff

# Load the Iris dataset and get it into the correct form
arff = Arff.loadarff("data/iris.arff")
data = convert(Matrix{Float32}, arff.data[:, 1:end-1])

num_data = size(data)[1]
num_features = size(data)[2]
num_classes = 3

mappings = Dict(:(Iris - setosa) =>  Float32[1.0, 0.0, 0.0],
                :(Iris - versicolor) => Float32[0.0, 1.0, 0.0],
                :(Iris - virginica) => Float32[0.0, 0.0, 1.0])
labels = Matrix{Float32}(num_data, num_classes)
for i in 1:num_data
    labels[i, :] = mappings[arff.data[i, end]]
end

# Split the dataset into train, validate, and test
train_x, train_y, test_x, test_y = DataPrep.splitdata(data, labels)
train_x, train_y, val_x, val_y = DataPrep.splitdata(train_x, train_y)
train_size = size(train_x)[1]
val_size = size(val_x)[1]
test_size = size(test_x)[1]

# ============================== NETWORK DEF ================================ #

# Hyperparameters
learning_rate = 0.1
num_epochs = 1000
batch_size = 1

# Layers
fc1, Wb1 = fc_layer("Layer1", num_features, 2 * num_features)
fc2, Wb2 = fc_layer("Layer2", 2 * num_features, num_classes, activation_fn=softmax)
optim = SGDOptimizer()

# The network definition
function classify(input::Matrix{Float32})
    h1 = fc1(input)
    return fc2(h1)
end

# =============================== TRAINING ================================== #
# Calculate the evaluation set accuracy and loss
function evaluate(x, y)
    n = size(x)[1]
    predictions = classify(x)
    p_maxvals, p_maxindices = findmax(predictions.data, 2)
    t_maxvals, t_maxindices = findmax(y, 2)
    correct = sum(p_maxindices .== t_maxindices)
    incorrect = n - correct
    return correct / n, incorrect / n
end

function evaluate_mse(x, y)
    n = size(x)[1]
    predictions = classify(x)
    return reduce_mean((predictions - y)^2.0).data[1, 1]
end

# Store data, and weights for stopping criteria
train_mse = Matrix{Float32}(num_epochs, 1)
val_mse = Matrix{Float32}(num_epochs, 1)
val_acc = Matrix{Float32}(num_epochs, 1)
steps_since_update = 0
most_steps = 10
best_mse = 1000
cached_wb1 = deepcopy(Wb1)
cached_wb2 = deepcopy(Wb2)
num_steps = 0
stopping_index = 0
function cache_model()
    cached_wb1[1].data = copy(Wb1[1].data)
    cached_wb1[2].data = copy(Wb1[2].data)
    cached_wb2[1].data = copy(Wb2[1].data)
    cached_wb2[2].data = copy(Wb2[2].data)
end

for i in 1:num_epochs
    # Do a training step
    shuffled_x, shuffled_y = DataPrep.shuffledata(train_x, train_y)
    for j in 1:train_size
        o = classify(shuffled_x[j:j, :])
        loss = reduce_mean(reduce_sum((o - shuffled_y[j:j, :])^2.0, axis=[2]))

        optimize!(optim, loss, step_size=learning_rate)
    end

    train_mse[i, 1] = evaluate_mse(train_x, train_y)
    val_mse[i, 1] = evaluate_mse(val_x, val_y)
    val_acc[i, 1], _ = evaluate(val_x, val_y)

    num_steps += 1
    steps_since_update += 1

    if val_mse[i, 1] < best_mse
        best_mse = val_mse[i, 1]
        cache_model()
        steps_since_update = 0
        stopping_index = i
    elseif steps_since_update == most_steps
        break
    end
end

# Set the weights back to where they should be
Wb1[1].data = cached_wb1[1].data
Wb1[2].data = cached_wb1[2].data
Wb2[1].data = cached_wb2[1].data
Wb2[2].data = cached_wb2[2].data

test_acc, test_loss = evaluate(test_x, test_y)
println("test: ", test_acc, ", ", test_loss)

function plot_eval()
    pyplot()
    plot(train_mse[1:num_steps, 1], label="training mse")
    plot!(val_mse[1:num_steps, 1], label="validation mse")
    plot!(val_acc[1:num_steps, 1], label="validation accuracy")
    vline!([stopping_index], label="best solution")
    title!("Training on the Iris Dataset")
    xaxis!("Epochs")
    yaxis!("Accuracy / MSE")
end
