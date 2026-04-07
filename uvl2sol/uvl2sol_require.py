#!/usr/bin/env python3
"""
uvl2sol_require.py

Reads a UVL (Universal Variability Language) feature model file and outputs
Solidity require() statements implementing isValidProduct() for SPL.sol,
following the methodology in Section III of the paper.

Usage:
    python3 uvl2sol_require.py <model.uvl>
    python3 uvl2sol_require.py <model.uvl> --feature-map features.json

Feature map JSON (maps feature names to SPL metadata-address variable names):
    {
        "ERC20":            "meta_ERC20",
        "Burnable":         "meta_Burnable",
        "Extra":            "meta_Extra",
        "Metadata":         "meta_Metadata",
        "Permit":           "meta_Permit",
        "CrossChain":       "meta_CrossChain",
        "SuperchainERC20":  "meta_SuperchainERC20",
        "OFT":              "meta_OFT"
    }

If --feature-map is omitted, variable names default to meta_<FeatureName>.
"""

import sys
import re
import json
import argparse
from dataclasses import dataclass, field
from typing import Optional, List, Dict, Any, Tuple

# ------------------------------------------------------------------------------
# Data model
# ------------------------------------------------------------------------------

GROUP_KEYWORDS = {"mandatory", "optional", "or", "alternative"}
CARDINALITY_RE = re.compile(r"^\[(\d+)\.\.([\d\*]+)\]$")


@dataclass
class ChildGroup:
    """A group of child features under a parent feature."""
    kind: str           # mandatory | optional | or | alternative | cardinality
    min_card: int       # minimum number of children that must be selected
    max_card: Any       # maximum: int or None (unbounded)
    children: List[str] = field(default_factory=list)


@dataclass
class Feature:
    name: str
    parent: Optional[str]
    child_groups: List[ChildGroup] = field(default_factory=list)


@dataclass
class FeatureModel:
    namespace: str
    root: str
    features: Dict[str, Feature]   # insertion-ordered (Python 3.7+)
    raw_constraints: List[str]


# ------------------------------------------------------------------------------
# UVL parser
# ------------------------------------------------------------------------------

def _normalize_lines(text: str) -> List[Tuple[int, str]]:
    """
    Convert raw text into (indent_level, content) pairs, skipping blanks and
    comments.  Detects the smallest non-zero indentation unit and uses it as
    one level (handles both tab- and space-indented files).
    """
    raw = text.splitlines()

    # Collect all non-zero raw indent widths to infer tab size
    raw_indents = []
    for line in raw:
        stripped = line.lstrip()
        if stripped and not stripped.startswith("//"):
            width = len(line) - len(stripped)
            if width > 0:
                raw_indents.append(width)

    # Tab size = GCD of observed indentations (defaults to 1)
    tab_size = 1
    if raw_indents:
        from math import gcd
        from functools import reduce
        tab_size = reduce(gcd, raw_indents)

    result = []
    for line in raw:
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue
        raw_width = len(line) - len(line.lstrip())
        level = raw_width // tab_size
        result.append((level, stripped))
    return result


def parse_uvl(text: str) -> FeatureModel:
    """Parse a UVL feature model text into a FeatureModel."""
    lines = _normalize_lines(text)

    namespace = "ProductLine"
    features: Dict[str, Feature] = {}
    root: Optional[str] = None
    raw_constraints: List[str] = []
    section = None

    # Stack entries: (indent_level, kind, payload)
    #   kind == "feature"  -> payload is the feature name (str)
    #   kind == "group"    -> payload is the ChildGroup object being filled
    stack: List[Tuple[int, str, Any]] = []

    for indent, content in lines:
        # -- Section headers ---------------------------------------------------
        if content == "features":
            section = "features"
            stack = []
            continue
        if content == "constraints":
            section = "constraints"
            continue
        if content.startswith("namespace"):
            parts = content.split(None, 1)
            namespace = parts[1].strip() if len(parts) > 1 else "ProductLine"
            continue

        if section == "constraints":
            raw_constraints.append(content)
            continue

        if section != "features":
            continue

        # -- Feature tree ------------------------------------------------------
        # Pop stack entries at the same or deeper indent
        while stack and stack[-1][0] >= indent:
            stack.pop()

        card_match = CARDINALITY_RE.match(content)
        is_group_kw = content in GROUP_KEYWORDS or card_match is not None

        if is_group_kw:
            # Find the nearest parent feature on the stack
            parent_name = None
            for _, kind, payload in reversed(stack):
                if kind == "feature":
                    parent_name = payload
                    break

            if parent_name is None:
                # Malformed UVL - skip
                continue

            if card_match:
                min_c = int(card_match.group(1))
                max_raw = card_match.group(2)
                max_c = None if max_raw == "*" else int(max_raw)
                group = ChildGroup(kind="cardinality", min_card=min_c, max_card=max_c)
            else:
                kw = content
                defaults = {
                    "mandatory":   (1, None),
                    "optional":    (0, None),
                    "or":          (1, None),
                    "alternative": (1, 1),
                }
                min_c, max_c = defaults[kw]
                group = ChildGroup(kind=kw, min_card=min_c, max_card=max_c)

            features[parent_name].child_groups.append(group)
            stack.append((indent, "group", group))

        else:
            # Feature name - find parent feature and current group
            parent_name: Optional[str] = None
            current_group: Optional[ChildGroup] = None

            for _, kind, payload in reversed(stack):
                if kind == "group" and current_group is None:
                    current_group = payload
                if kind == "feature" and parent_name is None:
                    parent_name = payload
                if current_group is not None and parent_name is not None:
                    break

            feat = Feature(name=content, parent=parent_name)
            features[content] = feat

            if root is None:
                root = content

            if current_group is not None:
                current_group.children.append(content)

            stack.append((indent, "feature", content))

    if root is None:
        raise ValueError("No root feature found in the UVL model")

    return FeatureModel(
        namespace=namespace,
        root=root,
        features=features,
        raw_constraints=raw_constraints,
    )


# ------------------------------------------------------------------------------
# Constraint expression parser  (UVL propositional logic →-> Solidity boolean)
# ------------------------------------------------------------------------------
#
# Operator precedence (low -> high):
#   <=>   biconditional (right-associative)
#   =>    implication   (right-associative)
#   |     disjunction
#   &     conjunction
#   !     negation (unary prefix)
#   atom / (expr)


def _tokenize(expr: str) -> List[str]:
    tokens = []
    i = 0
    while i < len(expr):
        if expr[i:i+3] == "<=>":
            tokens.append("<=>"); i += 3
        elif expr[i:i+2] == "=>":
            tokens.append("=>"); i += 2
        elif expr[i:i+2] == "&&":
            tokens.append("&"); i += 2
        elif expr[i:i+2] == "||":
            tokens.append("|"); i += 2
        elif expr[i] in "&|!()":
            tokens.append(expr[i]); i += 1
        elif expr[i].isspace():
            i += 1
        elif expr[i].isalnum() or expr[i] == "_":
            j = i
            while j < len(expr) and (expr[j].isalnum() or expr[j] == "_"):
                j += 1
            tokens.append(expr[i:j]); i = j
        else:
            i += 1
    return tokens


class _ExprParser:
    """Recursive descent parser for UVL propositional constraints."""

    def __init__(self, tokens: List[str], has_map: Dict[str, str]):
        self.tokens = tokens
        self.pos = 0
        self.has_map = has_map  # feature name -> "has<Name>" expression

    def _peek(self) -> Optional[str]:
        return self.tokens[self.pos] if self.pos < len(self.tokens) else None

    def _consume(self) -> str:
        t = self.tokens[self.pos]
        self.pos += 1
        return t

    def parse(self) -> str:
        return self._biconditional()

    def _biconditional(self) -> str:
        left = self._implication()
        if self._peek() == "<=>":
            self._consume()
            right = self._biconditional()
            return f"(({left} && {right}) || (!{left} && !{right}))"
        return left

    def _implication(self) -> str:
        left = self._or()
        if self._peek() == "=>":
            self._consume()
            right = self._implication()   # right-associative
            return f"(!{left} || {right})"
        return left

    def _or(self) -> str:
        left = self._and()
        while self._peek() == "|":
            self._consume()
            right = self._and()
            left = f"({left} || {right})"
        return left

    def _and(self) -> str:
        left = self._not()
        while self._peek() == "&":
            self._consume()
            right = self._not()
            left = f"({left} && {right})"
        return left

    def _not(self) -> str:
        if self._peek() == "!":
            self._consume()
            operand = self._atom()
            # Collapse double negation
            if operand.startswith("!"):
                return operand[1:]
            return f"!{operand}"
        return self._atom()

    def _atom(self) -> str:
        t = self._peek()
        if t is None:
            return "true"
        if t == "(":
            self._consume()
            expr = self.parse()
            if self._peek() == ")":
                self._consume()
            return expr
        self._consume()
        return self.has_map.get(t, f"has{t}")


def _constraint_to_sol(raw: str, has_map: Dict[str, str]) -> str:
    """Convert a raw UVL constraint string to a Solidity boolean expression."""
    tokens = _tokenize(raw)
    if not tokens:
        return "true"
    parser = _ExprParser(tokens, has_map)
    return parser.parse()


def _constraint_to_human(raw: str) -> str:
    """Best-effort human-readable version of the constraint for error messages."""
    return raw.replace("=>", "implies").replace("<=>", "iff").replace("&", "and").replace("|", "or")


# ------------------------------------------------------------------------------
# Solidity code generation
# ------------------------------------------------------------------------------

def _has(name: str) -> str:
    return f"has{name}"


def _meta(name: str, feature_map: Dict[str, str]) -> str:
    return feature_map.get(name, f"meta_{name}")


def _build_has_map(model: FeatureModel, feature_map: Dict[str, str]) -> Dict[str, str]:
    """Map every non-root feature name to its Solidity has-variable name."""
    return {
        name: _has(name)
        for name in model.features
        if name != model.root
    }


def generate_solidity(
    model: FeatureModel,
    feature_map: Dict[str, str],
    infra_features: List[str],
) -> str:
    """Return a Solidity code snippet implementing isValidProduct() body.

    infra_features: ordered list of infrastructure feature names (e.g.
    ["DiamondCut", "DiamondLoupe", "Ownership"]) that are required in every
    product but are not part of the UVL feature model.  Each gets a bool
    declaration, a branch in the scan loop, and a require() that it is present.
    """

    root = model.root
    # Non-root model features in declaration order
    feature_names = [n for n in model.features if n != root]
    has_map = _build_has_map(model, feature_map)

    lines: List[str] = []

    # -- Header ----------------------------------------------------------------
    infra_label = (", ".join(infra_features) + " (infra)") if infra_features else ""
    all_label   = ", ".join(filter(None, [infra_label, ", ".join(feature_names)]))
    lines += [
        f"// Generated by uvl2sol_require.py",
        f"// Namespace : {model.namespace}",
        f"// Root      : {root}",
        f"// Features  : {all_label}",
        "",
    ]

    # -- Presence flags --------------------------------------------------------
    lines.append("// -- Feature presence flags " + "-" * 53)
    for name in infra_features:
        lines.append(f"bool {_has(name)} = false;")
    for name in feature_names:
        lines.append(f"bool {_has(name)} = false;")
    lines.append("")

    # -- Parse loop ------------------------------------------------------------
    lines.append("// -- Scan _features and set flags " + "-" * 47)
    lines.append("for (uint256 i = 0; i < _features.length; i++) {")
    lines.append("    address f = _features[i];")
    lines.append('    require(_isKnownMeta[f], "SPL: unknown feature address");')
    lines.append("")

    first = True
    for name in infra_features + feature_names:
        meta_var = _meta(name, feature_map)
        has_var  = _has(name)
        kw = "    if" if first else "    else if"
        lines.append(f"{kw} (f == {meta_var}) {has_var} = true;")
        first = False

    lines.append("}")
    lines.append("")

    # -- Infrastructure requirements -------------------------------------------
    if infra_features:
        lines.append("// -- Infrastructure requirements " + "-" * 49)
        for name in infra_features:
            lines.append(f'require({_has(name)}, "SPL: {name} facet is required");')
        lines.append("")

    # -- Hierarchy constraints -------------------------------------------------
    lines.append("// -- Hierarchy constraints " + "-" * 54)
    hier_requires = _hierarchy_requires(model, feature_map, has_map)
    lines += hier_requires
    lines.append("")

    # -- Explicit UVL constraints ----------------------------------------------
    if model.raw_constraints:
        lines.append("// -- Cross-tree constraints " + "-" * 53)
        for raw in model.raw_constraints:
            sol_expr = _constraint_to_sol(raw, has_map)
            human    = _constraint_to_human(raw)
            lines.append(f'require({sol_expr}, "SPL: {human}");')
        lines.append("")

    return "\n".join(lines)


def _hierarchy_requires(
    model: FeatureModel,
    feature_map: Dict[str, str],
    has_map: Dict[str, str],
) -> List[str]:
    """
    Generate require() statements derived from the feature-model hierarchy:
      - Mandatory children must always be selected (or when parent is selected)
      - Non-mandatory children imply their parent
      - Or-group: at least one child when parent is selected
      - Alternative-group / [1..1]: exactly one child when parent is selected
      - [0..1] cardinality: at most one child (pairwise mutual exclusion)
      - [m..n] in general: lower bound + upper bound checks
    """
    root = model.root
    req: List[str] = []

    for parent_name, parent_feat in model.features.items():
        is_root = (parent_name == root)
        parent_has = _has(parent_name)

        for group in parent_feat.child_groups:
            children = group.children
            if not children:
                continue

            child_has = [_has(c) for c in children]

            # -- Children imply parent (skip for root - root is always selected) 
            if not is_root:
                for c in children:
                    req.append(
                        f'require(!{_has(c)} || {parent_has}, '
                        f'"SPL: {c} requires {parent_name}");'
                    )

            # -- Group-level constraint ----------------------------------------
            kind = group.kind

            if kind == "mandatory":
                for c in children:
                    if is_root:
                        req.append(f'require({_has(c)}, "SPL: {c} is mandatory");')
                    else:
                        req.append(
                            f'require(!{parent_has} || {_has(c)}, '
                            f'"SPL: {parent_name} requires {c}");'
                        )

            elif kind == "or":
                or_expr = " || ".join(child_has)
                names   = "{" + ", ".join(children) + "}"
                if is_root:
                    req.append(f'require({or_expr}, "SPL: at least one of {names} must be selected");')
                else:
                    req.append(
                        f'require(!{parent_has} || ({or_expr}), '
                        f'"SPL: {parent_name} requires at least one of {names}");'
                    )

            elif kind == "alternative":
                req += _exactly_one_requires(
                    children, child_has, parent_name, parent_has, is_root
                )

            elif kind == "optional":
                pass  # No group-level constraint; children-imply-parent already added

            elif kind == "cardinality":
                min_c = group.min_card
                max_c = group.max_card  # None = unbounded

                # Lower bound
                if min_c == 1 and max_c == 1:
                    req += _exactly_one_requires(
                        children, child_has, parent_name, parent_has, is_root
                    )
                elif min_c >= 1:
                    # at-least-min: generate for min_c == 1 (or expression)
                    if min_c == 1:
                        or_expr = " || ".join(child_has)
                        names   = "{" + ", ".join(children) + "}"
                        if is_root:
                            req.append(f'require({or_expr}, "SPL: at least one of {names} must be selected");')
                        else:
                            req.append(
                                f'require(!{parent_has} || ({or_expr}), '
                                f'"SPL: {parent_name} requires at least one of {names}");'
                            )
                    else:
                        # min_c >= 2: emit a Solidity uint count check
                        count_expr = " + ".join([f"(uint256({h} ? 1 : 0))" for h in child_has])
                        names = "{" + ", ".join(children) + "}"
                        lb_cond = f"({count_expr}) >= {min_c}"
                        if is_root:
                            req.append(f'require({lb_cond}, "SPL: at least {min_c} of {names} must be selected");')
                        else:
                            req.append(f'require(!{parent_has} || {lb_cond}, "SPL: {parent_name} requires at least {min_c} of {names}");')

                # Upper bound
                if max_c is not None:
                    if max_c == 0:
                        # [0..0]: none may be selected
                        for c, ch in zip(children, child_has):
                            req.append(f'require(!{ch}, "SPL: {c} must not be selected");')
                    elif max_c == 1:
                        # at-most-one: pairwise mutual exclusion
                        req += _pairwise_mutex(children, child_has)
                    else:
                        # max_c >= 2: emit a count check
                        count_expr = " + ".join([f"(uint256({h} ? 1 : 0))" for h in child_has])
                        names = "{" + ", ".join(children) + "}"
                        ub_cond = f"({count_expr}) <= {max_c}"
                        if is_root:
                            req.append(f'require({ub_cond}, "SPL: at most {max_c} of {names} may be selected");')
                        else:
                            req.append(f'require(!{parent_has} || {ub_cond}, "SPL: {parent_name}: at most {max_c} of {names} may be selected");')

    return req


def _exactly_one_requires(
    children: List[str],
    child_has: List[str],
    parent_name: str,
    parent_has: str,
    is_root: bool,
) -> List[str]:
    """Emit requires for exactly-one (alternative / [1..1]) group."""
    req = []
    names = "{" + ", ".join(children) + "}"

    # At least one
    or_expr = " || ".join(child_has)
    if is_root:
        req.append(f'require({or_expr}, "SPL: exactly one of {names} must be selected");')
    else:
        req.append(
            f'require(!{parent_has} || ({or_expr}), '
            f'"SPL: {parent_name} requires exactly one of {names}");'
        )

    # Pairwise mutual exclusion (at most one)
    req += _pairwise_mutex(children, child_has)
    return req


def _pairwise_mutex(children: List[str], child_has: List[str]) -> List[str]:
    """Emit pairwise not-both requires for mutual exclusion."""
    req = []
    for i in range(len(children)):
        for j in range(i + 1, len(children)):
            ci, cj = child_has[i], child_has[j]
            ni, nj = children[i], children[j]
            req.append(
                f'require(!({ci} && {cj}), "SPL: {ni} and {nj} are mutually exclusive");'
            )
    return req


# ------------------------------------------------------------------------------
# CLI
# ------------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(
        description="Convert a UVL feature model to Solidity require() statements for isValidProduct()."
    )
    ap.add_argument("uvl_file", help="Path to the .uvl feature model file")
    ap.add_argument(
        "--feature-map", metavar="JSON",
        help="JSON file mapping feature names to Solidity metadata-address variable names"
    )
    ap.add_argument(
        "--infra", metavar="NAMES",
        help=(
            "Comma-separated list of infrastructure feature names that are "
            "required in every product but absent from the UVL model "
            "(e.g. 'DiamondCut,DiamondLoupe,Ownership').  Each gets a bool "
            "declaration, a branch in the scan loop, and a require() check."
        ),
        default="",
    )
    ap.add_argument(
        "--output", metavar="FILE",
        help="Write output to FILE instead of stdout"
    )
    args = ap.parse_args()

    # Load UVL
    try:
        with open(args.uvl_file, "r") as f:
            uvl_text = f.read()
    except FileNotFoundError:
        print(f"Error: file not found: {args.uvl_file}", file=sys.stderr)
        sys.exit(1)

    # Load optional feature map
    feature_map: Dict[str, str] = {}
    if args.feature_map:
        try:
            with open(args.feature_map, "r") as f:
                feature_map = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError) as e:
            print(f"Error loading feature map: {e}", file=sys.stderr)
            sys.exit(1)

    # Parse and generate
    try:
        model = parse_uvl(uvl_text)
    except ValueError as e:
        print(f"Parse error: {e}", file=sys.stderr)
        sys.exit(1)

    infra_features = [n.strip() for n in args.infra.split(",") if n.strip()]
    output = generate_solidity(model, feature_map, infra_features)

    if args.output:
        with open(args.output, "w") as f:
            f.write(output)
        print(f"Written to {args.output}", file=sys.stderr)
    else:
        print(output)


if __name__ == "__main__":
    main()
