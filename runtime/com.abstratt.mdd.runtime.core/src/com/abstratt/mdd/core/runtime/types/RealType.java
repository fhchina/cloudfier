package com.abstratt.mdd.core.runtime.types;

import com.abstratt.mdd.core.runtime.ExecutionContext;

public class RealType extends NumberType<Double> {
    public static RealType fromString(java.lang.String stringValue) {
        return new RealType(Double.parseDouble(stringValue));
    }

    public static RealType fromValue(double value) {
        return new RealType(value);
    }

    /**
     *
     */
    private static final long serialVersionUID = 1L;

    public RealType(double value) {
        this.value = value;
    }

    /*
     * (non-Javadoc)
     * 
     * @see
     * com.abstratt.mdd.core.runtime.types.NumberType#add(com.abstratt.mdd.core
     * .runtime.types.NumberType)
     */
    @Override
    public NumberType<Double> add(ExecutionContext context, NumberType<?> another) {
        return new RealType(value + another.asDouble());
    }

    @Override
    public NumberType<Double> divide(ExecutionContext context, NumberType<?> number) {
        return new RealType(value / number.asDouble());
    }

    @Override
    public String getClassifierName() {
        return "mdd_types::Double";
    }

    @Override
    public NumberType multiply(ExecutionContext context, NumberType number) {
        return new RealType(value * number.asDouble());
    }

    @Override
    public NumberType subtract(ExecutionContext context) {
        return new RealType(-value);
    }

    @Override
    public NumberType subtract(ExecutionContext context, NumberType another) {
        return new RealType(value - another.asDouble());
    }

    @Override
    protected RealType asReal() {
        // one less object
        return this;
    }
}