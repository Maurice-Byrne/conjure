
export function appendControls() {

    console.log("CONTROLS");
    var step = d3.select("#controls")
        .append('div')
        .classed('col-xs-1', true);

    console.log(step);
    step.append('input')
        .classed('form-control', true)
        .attr('type', 'text')
        .attr('name', 'textInput')
        .attr('value', '1')
        .attr('id', 'stepSize')
}
        // d3.select("#controls")
        //     .append("input")
        //     .attr("type", "button")
        //     .attr("value", "Collapse All")
        //     .on("click", collapser);

//         d3.select("#controls")
//             .append("input")
//             .attr("type", "button")
//             .attr("value", "Expand All")
//             .on("click", expander);

//         d3.select("#controls")
//             .append("input")
//             .attr("type", "button")
//             .attr("value", "Find Root")
//             .on("click", () => {
//                 selectNode(root.minionID);
//                 focusNode(nodeMap[root.minionID]);
//             });

//         d3.select("#controls")
//             .append("input")
//             .attr("type", "button")
//             .attr("value", "Previous")
//             .on("click", () => {
//                 previous();
//             });

//         d3.select("#controls")
//             .append("input")
//             .attr("type", "button")
//             .attr("value", "Next")
//             .on("click", () => {
//                 next();
//             });

//         d3.select("#controls")
//             .append("input")
//             .attr("type", "button")
//             .attr("value", "Toggle")
//             .on("click", () => {
//                 nodeToggle(nodeMap[selectedNode]);
//             });

//         d3.select("#controls")
//             .append('label')
//             .text("Pretty")
//             .append("input")
//             .attr("checked", true)
//             .attr("type", "checkbox")
//             .attr("id", "check")
//             .on("change", () => {
//                 // console.log("Changed!")
//                 showDomains(selectedNode)
//             })
//         // .attr("onClick", () => {
//         //     console.log("hello");
//         //     showDomains(selectedNode)
//         // });