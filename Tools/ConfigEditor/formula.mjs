// Shared by browser preview, validation and exporter. Never eval/Function/load user formulas.
export const operations = {
  '+': [3, 2], '-': [4, 2], '*': [5, 2], '/': [6, 2], '%': [7, 2], '^': [8, 2],
  neg: [9, 1], min: [16, 2], max: [17, 2], floor: [18, 1], ceil: [19, 1], abs: [20, 1], clamp: [21, 3]
};
export function compileFormula(source, variables = []) {
  if (typeof source !== 'string' || !source.trim() || source.length > 2048) throw new Error('Formula must contain 1–2048 characters');
  const tokens = []; const regex = /\s*(?:(\d+(?:\.\d*)?(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)|([A-Za-z_][A-Za-z0-9_]*)|([+\-*/%^(),]))/gy;
  let position = 0;
  while (position < source.length) {
    if (!source.slice(position).trim()) break;
    regex.lastIndex = position;
    const match = regex.exec(source);
    if (!match) throw new Error(`Invalid formula token at character ${position + 1}`);
    tokens.push(match[1] ? { number: Number(match[1]) } : match[2] || match[3]);
    position = regex.lastIndex;
  }
  if (tokens.length > 256) throw new Error('Formula is too complex (maximum 256 tokens)');
  let index = 0; const output = [];
  const expect = token => { if (tokens[index++] !== token) throw new Error(`Expected '${token}'`); };
  function expression(minimum = 0) {
    const token = tokens[index++];
    if (token && typeof token === 'object') {
      if (!Number.isFinite(token.number)) throw new Error('Non-finite formula constant');
      output.push([1, token.number]);
    } else if (token === '-' || token === '+') {
      expression(25); if (token === '-') output.push([9]);
    } else if (token === '(') {
      expression(); expect(')');
    } else if (typeof token === 'string' && /^[A-Za-z_]/.test(token)) {
      if (tokens[index] === '(') {
        if (!Object.hasOwn(operations, token) || operations[token][0] < 16) throw new Error(`Unknown function '${token}'`);
        index++; const [opcode, arity] = operations[token];
        for (let i = 0; i < arity; i++) { if (i) expect(','); expression(); }
        expect(')'); output.push([opcode]);
      } else {
        if (!variables.includes(token)) throw new Error(`Unknown variable '${token}'`);
        output.push([2, token]);
      }
    } else throw new Error('Expected a number, variable or expression');
    const binding = { '+': 10, '-': 10, '*': 20, '/': 20, '%': 20, '^': 30 };
    while (Object.hasOwn(binding, tokens[index]) && binding[tokens[index]] >= minimum) {
      const operator = tokens[index++];
      expression(binding[operator] + (operator === '^' ? 0 : 1));
      output.push([operations[operator][0]]);
    }
  }
  expression();
  if (index !== tokens.length) throw new Error(`Unexpected token '${tokens[index]}'`);
  return output;
}
export function evaluateFormula(program, variables) {
  const stack = [];
  for (const [op, operand] of program) {
    if (op === 1) { stack.push(operand); continue; }
    if (op === 2) {
      if (!Object.hasOwn(variables, operand) || typeof variables[operand] !== 'number' || !Number.isFinite(variables[operand])) throw new Error(`Missing/non-finite variable '${operand}'`);
      stack.push(variables[operand]); continue;
    }
    const arity = Object.values(operations).find(value => value[0] === op)?.[1];
    if (!arity || stack.length < arity) throw new Error('Invalid formula bytecode');
    const args = stack.splice(-arity); const [a, b, c] = args;
    if ((op === 6 || op === 7) && b === 0) throw new Error('Division by zero');
    if (op === 21 && b > c) throw new Error('clamp minimum exceeds maximum');
    const value = ({ 3: () => a + b, 4: () => a - b, 5: () => a * b, 6: () => a / b,
      7: () => a - Math.floor(a / b) * b, 8: () => a ** b, 9: () => -a,
      16: () => Math.min(a, b), 17: () => Math.max(a, b), 18: () => Math.floor(a),
      19: () => Math.ceil(a), 20: () => Math.abs(a), 21: () => Math.min(Math.max(a, b), c) })[op]();
    if (!Number.isFinite(value)) throw new Error('Non-finite formula result');
    stack.push(value);
  }
  if (stack.length !== 1) throw new Error('Invalid formula stack');
  return stack[0];
}
